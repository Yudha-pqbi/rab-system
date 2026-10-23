-- Refuse to overwrite a concurrently changed database function.
DO $baseline_guard$
BEGIN
 IF pg_get_functiondef('public.rab_save_with_project_identity_v1(jsonb,text)'::regprocedure) IS DISTINCT FROM $expected_0$CREATE OR REPLACE FUNCTION public.rab_save_with_project_identity_v1(p_payload jsonb, p_existing_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET statement_timeout TO '15s'
AS $function$
DECLARE r public.projects%rowtype; identity jsonb; source_id text; code text;
BEGIN
 IF jsonb_typeof(p_payload) IS DISTINCT FROM 'object' OR octet_length(p_payload::text)>5000000 THEN RAISE EXCEPTION 'Payload RAB tidak valid';END IF;
 r:=jsonb_populate_record(NULL::public.projects,p_payload);
 IF nullif(btrim(r.client_name),'') IS NULL OR nullif(btrim(r.project_title),'') IS NULL THEN RAISE EXCEPTION 'Nama client dan service wajib diisi';END IF;
 IF r.status IS DISTINCT FROM 'APPROVED' THEN RAISE EXCEPTION 'Status penyimpanan RAB tidak sesuai';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('RAB_NUMERIC_PARENT:'||upper(btrim(r.client_name)),0));
 IF nullif(p_existing_id,'') IS NOT NULL THEN
  SELECT p.project_id INTO source_id FROM public.projects p WHERE p.project_id=p_existing_id AND p.status<>'DELETED' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RAB yang diedit tidak tersedia; muat ulang daftar';END IF;
  IF r.project_id IS DISTINCT FROM source_id THEN RAISE EXCEPTION 'Identitas dokumen RAB tidak sesuai';END IF;
  UPDATE public.projects SET client_name=r.client_name,client_location=r.client_location,project_area=r.project_area,project_title=r.project_title,top_days=r.top_days,cost_project=r.cost_project,management_fee_percent=r.management_fee_percent,management_fee_value=r.management_fee_value,rounded_before_tax=r.rounded_before_tax,total_after_tax=r.total_after_tax,cost_manpower=r.cost_manpower,cost_machinery=r.cost_machinery,cost_chemical=r.cost_chemical,cost_consumable=r.cost_consumable,details_json=r.details_json,status=r.status WHERE project_id=source_id;
 ELSE
  source_id:=coalesce(nullif(r.project_id,''),gen_random_uuid()::text);
  IF source_id !~* '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' THEN RAISE EXCEPTION 'Dokumen baru memakai referensi internal UUID; Project ID diterbitkan numerik oleh RAB';END IF;
  INSERT INTO public.projects(project_id,client_name,client_location,project_area,project_title,top_days,cost_project,management_fee_percent,management_fee_value,rounded_before_tax,total_after_tax,cost_manpower,cost_machinery,cost_chemical,cost_consumable,details_json,status) VALUES(source_id,r.client_name,r.client_location,r.project_area,r.project_title,r.top_days,r.cost_project,r.management_fee_percent,r.management_fee_value,r.rounded_before_tax,r.total_after_tax,r.cost_manpower,r.cost_machinery,r.cost_chemical,r.cost_consumable,r.details_json,r.status);
 END IF;
 SELECT c.project_code INTO code FROM public.canonical_project_rab_links_candidate_v1 l JOIN public.canonical_projects_candidate_v1 c ON c.project_no=l.canonical_project_no AND c.status='ACTIVE' WHERE l.rab_project_id=source_id AND l.link_status='ACTIVE';
 -- Numeric identity is assigned by the private AFTER INSERT trigger; existing links remain authoritative.
 IF code IS NULL OR code !~ '^[0-9]+$' THEN RAISE EXCEPTION 'Identitas project perlu dipastikan: %. Tidak ada data baru yang disimpan.',coalesce(identity->>'action','REVIEW');END IF;
 RETURN jsonb_build_object('status','SAVED','project_id',code,'source_record_id',source_id,'identity_policy','NUMERIC_CANONICAL','legacy_code_created',false);
END $function$
$expected_0$ THEN
  RAISE EXCEPTION 'RAB-SAVE-020 baseline changed: rab_save_with_project_identity_v1';
 END IF;
 IF pg_get_functiondef('public.rab_canonical_assign_parent_identity_candidate_v2(text,text)'::regprocedure) IS DISTINCT FROM $expected_1$CREATE OR REPLACE FUNCTION public.rab_canonical_assign_parent_identity_candidate_v2(p_rab_project_id text, p_evidence_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_rab record;
  v_authority record;
  v_existing_no bigint;
  v_existing_code text;
  v_preview jsonb;
  v_action text;
  v_project_no bigint;
  v_project_code text;
begin
  select p.project_id,p.client_name,p.project_title,p.project_area,p.status
  into v_rab
  from public.projects p
  where p.project_id=p_rab_project_id;

  if not found then
    return jsonb_build_object('action','NOT_FOUND','rab_project_id',p_rab_project_id);
  end if;

  if v_rab.status='DELETED' then
    return jsonb_build_object('action','SKIP_DELETED','rab_project_id',p_rab_project_id);
  end if;

  select a.governed_client_name,a.authority_status,a.governed_client_count
  into v_authority
  from public.rab_client_authority_snapshot_candidate_v1 a
  where a.normalized_match_name =
    upper(trim(regexp_replace(v_rab.client_name,'[^A-Za-z0-9]+',' ','g')))
    and a.authority_status='GOVERNED'
    and a.governed_client_count=1
  limit 1;

  if not found then
    return jsonb_build_object(
      'action','CLIENT_AUTHORITY_REVIEW',
      'rab_project_id',p_rab_project_id,
      'source_client_name',v_rab.client_name
    );
  end if;

  select cp.project_no,cp.project_code
  into v_existing_no,v_existing_code
  from public.canonical_project_rab_links_candidate_v1 l
  join public.canonical_projects_candidate_v1 cp
    on cp.project_no=l.canonical_project_no
  where l.rab_project_id=p_rab_project_id
    and l.link_status='ACTIVE'
  order by l.id desc
  limit 1;

  if found then
    return jsonb_build_object(
      'action','ALREADY_LINKED',
      'rab_project_id',p_rab_project_id,
      'project_code',v_existing_code,
      'project_no',v_existing_no,
      'rab_budget_status',v_rab.status,
      'identity_only',true
    );
  end if;

  v_preview := public.rab_canonical_preview_assignment_candidate_v1(
    v_rab.client_name,
    v_rab.project_title,
    v_rab.project_area
  );
  v_action := v_preview->>'action';

  if v_action='USE_EXISTING' then
    select cp.project_no,cp.project_code
    into v_project_no,v_project_code
    from public.canonical_projects_candidate_v1 cp
    where cp.project_code=v_preview->>'project_code'
      and cp.status='ACTIVE'
    limit 1;

    if not found then
      return jsonb_build_object(
        'action','REVIEW',
        'reason','Preview pointed to a non-active canonical project.',
        'preview',v_preview
      );
    end if;
  elsif v_action='ISSUE_NEW' then
    insert into public.canonical_projects_candidate_v1 (
      project_name,client_name,primary_service,status,source_mode
    )
    values (
      v_authority.governed_client_name || ' · ' || trim(v_rab.project_title),
      v_authority.governed_client_name,
      trim(v_rab.project_title),
      'ACTIVE',
      'SHADOW_CANDIDATE'
    )
    returning project_no,project_code
    into v_project_no,v_project_code;
  else
    return v_preview || jsonb_build_object(
      'rab_project_id',p_rab_project_id,
      'identity_only',true
    );
  end if;

  insert into public.canonical_project_rab_links_candidate_v1 (
    canonical_project_no,rab_project_id,link_status,effective_from,evidence_note
  )
  values (
    v_project_no,
    p_rab_project_id,
    'ACTIVE',
    current_date,
    'IDENTITY_ONLY_PARENT_CANDIDATE_V2: source RAB budget status='
      || coalesce(v_rab.status,'UNKNOWN')
      || '; Project ID identity is independent from RAB budget approval. '
      || coalesce(p_evidence_note,'')
  );

  insert into public.canonical_project_aliases_candidate_v1 (
    canonical_project_no,source_system,alias_type,alias_value
  )
  values (v_project_no,'RAB','RAB_PROJECT_ID',p_rab_project_id)
  on conflict do nothing;

  return jsonb_build_object(
    'action',case when v_action='USE_EXISTING' then 'LINKED_EXISTING_IDENTITY_ONLY' else 'ISSUED_NEW_IDENTITY_ONLY' end,
    'rab_project_id',p_rab_project_id,
    'project_code',v_project_code,
    'project_no',v_project_no,
    'rab_budget_status',v_rab.status,
    'governed_client_name',v_authority.governed_client_name,
    'identity_only',true,
    'budget_approval_changed',false
  );
end;
$function$
$expected_1$ THEN
  RAISE EXCEPTION 'RAB-SAVE-020 baseline changed: rab_canonical_assign_parent_identity_candidate_v2';
 END IF;
 IF pg_get_functiondef('glpp.rab_numeric_parent_after_insert_v1()'::regprocedure) IS DISTINCT FROM $expected_2$CREATE OR REPLACE FUNCTION glpp.rab_numeric_parent_after_insert_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF TG_TABLE_SCHEMA<>'public' OR TG_TABLE_NAME<>'projects' OR TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Invalid numeric identity trigger target';END IF;
 IF NEW.status<>'DELETED' THEN
  PERFORM public.rab_canonical_assign_parent_identity_candidate_v2(NEW.project_id,'PROJECT-IDENTITY-005: numeric parent assignment following permitted RAB insert; source amounts and approval status unchanged.');
 END IF;
 RETURN NEW;
END $function$
$expected_2$ THEN
  RAISE EXCEPTION 'RAB-SAVE-020 baseline changed: rab_numeric_parent_after_insert_v1';
 END IF;
END $baseline_guard$;

-- RAB-SAVE-020 | Repair existing canonical assignment and preserve failure reasons.
-- Financial calculations, frontend, source budgets and access grants are unchanged.

CREATE OR REPLACE FUNCTION public.rab_canonical_assign_parent_identity_candidate_v2(p_rab_project_id text, p_evidence_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_rab record;
  v_authority record;
  v_existing_no bigint;
  v_existing_code text;
  v_preview jsonb;
  v_action text;
  v_project_no bigint;
  v_project_code text;
begin
  select p.project_id,p.client_name,p.project_title,p.project_area,p.status
  into v_rab
  from public.projects p
  where p.project_id=p_rab_project_id;

  if not found then
    return jsonb_build_object('action','NOT_FOUND','rab_project_id',p_rab_project_id);
  end if;

  if v_rab.status='DELETED' then
    return jsonb_build_object('action','SKIP_DELETED','rab_project_id',p_rab_project_id);
  end if;

  select a.governed_client_name,a.authority_status,a.governed_client_count
  into v_authority
  from public.rab_client_authority_snapshot_candidate_v1 a
  where a.normalized_match_name =
    upper(trim(regexp_replace(v_rab.client_name,'[^A-Za-z0-9]+',' ','g')))
  limit 1;

  -- RAB-SAVE-020: an established canonical identity remains authoritative
  -- when the secondary client snapshot lacks a row. New issuance still
  -- requires a single GOVERNED client; explicit negative decisions are kept.

  select cp.project_no,cp.project_code
  into v_existing_no,v_existing_code
  from public.canonical_project_rab_links_candidate_v1 l
  join public.canonical_projects_candidate_v1 cp
    on cp.project_no=l.canonical_project_no and cp.status='ACTIVE'
  where l.rab_project_id=p_rab_project_id
    and l.link_status='ACTIVE'
  order by l.id desc
  limit 1;

  if found then
    return jsonb_build_object(
      'action','ALREADY_LINKED',
      'rab_project_id',p_rab_project_id,
      'project_code',v_existing_code,
      'project_no',v_existing_no,
      'rab_budget_status',v_rab.status,
      'identity_only',true
    );
  end if;

  if v_authority.authority_status in ('AMBIGUOUS','NON_CLIENT')
     or coalesce(v_authority.governed_client_count,0)>1 then
    return jsonb_build_object(
      'action',case when v_authority.authority_status='NON_CLIENT'
        then 'CLIENT_NOT_ELIGIBLE' else 'CLIENT_AUTHORITY_AMBIGUOUS' end,
      'reason','Client authority has an explicit non-client or ambiguous decision.',
      'rab_project_id',p_rab_project_id,
      'source_client_name',v_rab.client_name
    );
  end if;

  v_preview := public.rab_canonical_preview_assignment_candidate_v1(
    v_rab.client_name,
    v_rab.project_title,
    v_rab.project_area
  );
  v_action := v_preview->>'action';

  if v_action='USE_EXISTING' then
    select cp.project_no,cp.project_code
    into v_project_no,v_project_code
    from public.canonical_projects_candidate_v1 cp
    where cp.project_code=v_preview->>'project_code'
      and cp.status='ACTIVE'
    limit 1;

    if not found then
      return jsonb_build_object(
        'action','REVIEW',
        'reason','Preview pointed to a non-active canonical project.',
        'preview',v_preview
      );
    end if;
  elsif v_action='ISSUE_NEW' then
    if v_authority.authority_status is distinct from 'GOVERNED'
       or v_authority.governed_client_count is distinct from 1 then
      return jsonb_build_object(
        'action','CLIENT_AUTHORITY_REVIEW',
        'reason','Issuing a new Project ID requires one verified client.',
        'rab_project_id',p_rab_project_id,
        'source_client_name',v_rab.client_name
      );
    end if;
    insert into public.canonical_projects_candidate_v1 (
      project_name,client_name,primary_service,status,source_mode
    )
    values (
      v_authority.governed_client_name || ' · ' || trim(v_rab.project_title),
      v_authority.governed_client_name,
      trim(v_rab.project_title),
      'ACTIVE',
      'SHADOW_CANDIDATE'
    )
    returning project_no,project_code
    into v_project_no,v_project_code;
  else
    return v_preview || jsonb_build_object(
      'rab_project_id',p_rab_project_id,
      'identity_only',true
    );
  end if;

  insert into public.canonical_project_rab_links_candidate_v1 (
    canonical_project_no,rab_project_id,link_status,effective_from,evidence_note
  )
  values (
    v_project_no,
    p_rab_project_id,
    'ACTIVE',
    current_date,
    'IDENTITY_ONLY_PARENT_CANDIDATE_V2: source RAB budget status='
      || coalesce(v_rab.status,'UNKNOWN')
      || '; Project ID identity is independent from RAB budget approval. '
      || coalesce(p_evidence_note,'')
  );

  insert into public.canonical_project_aliases_candidate_v1 (
    canonical_project_no,source_system,alias_type,alias_value
  )
  values (v_project_no,'RAB','RAB_PROJECT_ID',p_rab_project_id)
  on conflict do nothing;

  return jsonb_build_object(
    'action',case when v_action='USE_EXISTING' then 'LINKED_EXISTING_IDENTITY_ONLY' else 'ISSUED_NEW_IDENTITY_ONLY' end,
    'rab_project_id',p_rab_project_id,
    'project_code',v_project_code,
    'project_no',v_project_no,
    'rab_budget_status',v_rab.status,
    'governed_client_name',v_authority.governed_client_name,
    'identity_only',true,
    'budget_approval_changed',false
  );
end;
$function$;


CREATE OR REPLACE FUNCTION glpp.rab_numeric_parent_after_insert_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_identity jsonb;
BEGIN
 IF TG_TABLE_SCHEMA<>'public' OR TG_TABLE_NAME<>'projects' OR TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Invalid numeric identity trigger target';END IF;
 IF NEW.status<>'DELETED' THEN
  v_identity := public.rab_canonical_assign_parent_identity_candidate_v2(NEW.project_id,'PROJECT-IDENTITY-005: numeric parent assignment following permitted RAB insert; source amounts and approval status unchanged.');
  -- Transaction-local diagnostics only; no new grant or external write.
  PERFORM set_config('rab.identity_diagnostic',
    jsonb_build_object('source_record_id',NEW.project_id,'result',v_identity)::text,true);
 END IF;
 RETURN NEW;
END $function$;


CREATE OR REPLACE FUNCTION public.rab_save_with_project_identity_v1(p_payload jsonb, p_existing_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET statement_timeout TO '15s'
AS $function$
DECLARE r public.projects%rowtype; identity jsonb; source_id text; code text;
BEGIN
 IF jsonb_typeof(p_payload) IS DISTINCT FROM 'object' OR octet_length(p_payload::text)>5000000 THEN RAISE EXCEPTION 'Payload RAB tidak valid';END IF;
 r:=jsonb_populate_record(NULL::public.projects,p_payload);
 IF nullif(btrim(r.client_name),'') IS NULL OR nullif(btrim(r.project_title),'') IS NULL THEN RAISE EXCEPTION 'Nama client dan service wajib diisi';END IF;
 IF r.status IS DISTINCT FROM 'APPROVED' THEN RAISE EXCEPTION 'Status penyimpanan RAB tidak sesuai';END IF;
 PERFORM set_config('rab.identity_diagnostic','{}',true);
 PERFORM pg_advisory_xact_lock(hashtextextended('RAB_NUMERIC_PARENT:'||upper(btrim(r.client_name)),0));
 IF nullif(p_existing_id,'') IS NOT NULL THEN
  SELECT p.project_id INTO source_id FROM public.projects p WHERE p.project_id=p_existing_id AND p.status<>'DELETED' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RAB yang diedit tidak tersedia; muat ulang daftar';END IF;
  IF r.project_id IS DISTINCT FROM source_id THEN RAISE EXCEPTION 'Identitas dokumen RAB tidak sesuai';END IF;
  UPDATE public.projects SET client_name=r.client_name,client_location=r.client_location,project_area=r.project_area,project_title=r.project_title,top_days=r.top_days,cost_project=r.cost_project,management_fee_percent=r.management_fee_percent,management_fee_value=r.management_fee_value,rounded_before_tax=r.rounded_before_tax,total_after_tax=r.total_after_tax,cost_manpower=r.cost_manpower,cost_machinery=r.cost_machinery,cost_chemical=r.cost_chemical,cost_consumable=r.cost_consumable,details_json=r.details_json,status=r.status WHERE project_id=source_id;
 ELSE
  source_id:=coalesce(nullif(r.project_id,''),gen_random_uuid()::text);
  IF source_id !~* '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' THEN RAISE EXCEPTION 'Dokumen baru memakai referensi internal UUID; Project ID diterbitkan numerik oleh RAB';END IF;
  INSERT INTO public.projects(project_id,client_name,client_location,project_area,project_title,top_days,cost_project,management_fee_percent,management_fee_value,rounded_before_tax,total_after_tax,cost_manpower,cost_machinery,cost_chemical,cost_consumable,details_json,status) VALUES(source_id,r.client_name,r.client_location,r.project_area,r.project_title,r.top_days,r.cost_project,r.management_fee_percent,r.management_fee_value,r.rounded_before_tax,r.total_after_tax,r.cost_manpower,r.cost_machinery,r.cost_chemical,r.cost_consumable,r.details_json,r.status);
 END IF;
 SELECT c.project_code INTO code FROM public.canonical_project_rab_links_candidate_v1 l JOIN public.canonical_projects_candidate_v1 c ON c.project_no=l.canonical_project_no AND c.status='ACTIVE' WHERE l.rab_project_id=source_id AND l.link_status='ACTIVE';
 -- Numeric identity is assigned by the private AFTER INSERT trigger; existing links remain authoritative.
 IF code IS NULL OR code !~ '^[0-9]+$' THEN
  identity:=coalesce(nullif(current_setting('rab.identity_diagnostic',true),'')::jsonb,'{}'::jsonb);
  IF identity->>'source_record_id' = source_id THEN
   identity:=coalesce(identity->'result','{}'::jsonb);
  ELSE
   identity:=jsonb_build_object('action','PROJECT_LINK_REVIEW','reason','Existing RAB has no active numeric Project ID link.');
  END IF;
  RAISE EXCEPTION USING
   ERRCODE='P0001',
   MESSAGE=format('RAB belum disimpan: klien "%s", layanan "%s", area "%s" [%s]. %s Tidak ada data baru yang disimpan.',
    left(r.client_name,160),left(r.project_title,160),left(coalesce(r.project_area,''),160),
    coalesce(identity->>'action','PROJECT_LINK_REVIEW'),
    CASE identity->>'action'
     WHEN 'CLIENT_AUTHORITY_REVIEW' THEN 'Nama klien belum terverifikasi; lengkapi pemetaan nama klien.'
     WHEN 'CLIENT_AUTHORITY_AMBIGUOUS' THEN 'Nama klien cocok dengan lebih dari satu klien; periksa pemetaan klien.'
     WHEN 'CLIENT_NOT_ELIGIBLE' THEN 'Nama ini tercatat sebagai non-klien; gunakan klien yang sesuai.'
     WHEN 'REVIEW_MULTI_PROJECT' THEN 'Lebih dari satu Project ID cocok; pastikan pemetaan area dan layanan.'
     WHEN 'BACKFILL_REVIEW_REQUIRED' THEN 'RAB terkait masih menunggu verifikasi Project ID.'
     ELSE 'Periksa tautan Project ID aktif untuk RAB ini.'
    END),
   DETAIL=identity::text,
   HINT='Perbaiki pemetaan klien/project sesuai evidence, kemudian simpan ulang; jangan membuat kode project duplikat.';
 END IF;
 RETURN jsonb_build_object('status','SAVED','project_id',code,'source_record_id',source_id,'identity_policy','NUMERIC_CANONICAL','legacy_code_created',false);
END $function$;


-- Verified aliases persist through snapshot rebuilds.
INSERT INTO public.rab_client_authority_alias_candidate_v1
 (source_client_name,normalized_source_name,governed_client_name,evidence_source,evidence_detail,confidence,is_active)
SELECT alias,upper(trim(regexp_replace(alias,'[^A-Za-z0-9]+',' ','g'))),'Djarum',
 'RAB_CANONICAL_AND_SIGNED_OFFER',
 'RAB-SAVE-020: existing DJARUM-SECURITY-V1 business-scope decision; six active Djarum Security RABs. Offer NIS/966-PRP/IX/2026 dated 2026-09-21 identifies PT DJARUM and DJARUM SKT WONOGIRI Security. Identity only; no budget imported.',
 'HIGH',true
FROM unnest(ARRAY['Djarum','PT DJARUM','DJARUM SKT WONOGIRI']) alias
ON CONFLICT (normalized_source_name) DO NOTHING;

DO $guard$
BEGIN
 IF (SELECT count(*) FROM public.rab_client_authority_alias_candidate_v1
     WHERE normalized_source_name IN ('DJARUM','PT DJARUM','DJARUM SKT WONOGIRI')
       AND governed_client_name='Djarum' AND is_active) <> 3 THEN
  RAISE EXCEPTION 'Djarum alias conflicts with existing client authority; abort RAB-SAVE-020.';
 END IF;
END $guard$;
SELECT public.rab_client_authority_refresh_snapshot_candidate_v1();
