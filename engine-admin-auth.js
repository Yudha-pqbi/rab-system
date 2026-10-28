/* ENGINE-SECURITY-028: isolated owner verification for destructive actions. */
(function (root) {
  'use strict';
  const allowedUrl = 'https://rljqyaycshwpoteoxgem.supabase.co';
  const actions = new Set(['GL_RESET_ALL', 'GL_DELETE_PERIOD', 'PAYVANCE_DELETE_BATCH', 'RAB_DELETE']);
  let pending = false;
  async function closeClient(client) {
    try { await client.auth.signOut({ scope: 'local' }); } catch (_) { /* memory-only session is discarded */ }
  }
  async function verify(client, action) {
    const { data, error } = await client.rpc('engine_admin_delete_access_v1', { p_action: action });
    if (error || data?.can_delete !== true || data?.action !== action) {
      throw new Error('Akun ini tidak memiliki izin hapus/reset. Gunakan akun owner yang telah disetujui.');
    }
    return data;
  }
  async function open({ url, key, action }) {
    if (url !== allowedUrl || !actions.has(action)) throw new Error('Tujuan verifikasi tidak sesuai.');
    if (pending) throw new Error('Selesaikan verifikasi yang sedang terbuka.');
    if (!root.supabase?.createClient) throw new Error('Modul autentikasi belum tersedia. Muat ulang halaman.');
    pending = true;
    const client = root.supabase.createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false, storageKey: 'nis-delete-verifier-memory-v1' },
      global: { fetch: (input, init = {}) => root.fetch(input, { ...init, signal: init.signal || AbortSignal.timeout(70000) }) }
    });
    const dialog = root.document.createElement('dialog');
    dialog.setAttribute('aria-labelledby', 'nis-delete-login-title');
    dialog.style.cssText = 'width:min(440px,92vw);border:1px solid #cbd5e1;border-radius:16px;padding:26px;color:#0f172a;background:#fff;box-shadow:0 20px 70px #0004;font:14px/1.5 system-ui';
    dialog.innerHTML = '<form><h2 id="nis-delete-login-title" style="font-size:21px;font-weight:700;margin:0 0 8px">Verifikasi owner</h2><p style="margin:0 0 18px">Hapus atau menonaktifkan RAB memerlukan akun owner. Verifikasi ini belum menghapus data.</p><label style="display:block">Email perusahaan<input name="email" type="email" autocomplete="username" required style="display:block;width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:10px;margin:5px 0 14px"></label><label style="display:block">Password<input name="password" type="password" autocomplete="current-password" required style="display:block;width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:10px;margin:5px 0 12px"></label><p role="status" aria-live="polite" style="min-height:22px;color:#9f1239"></p><div style="display:flex;justify-content:flex-end;gap:10px"><button type="button" data-cancel style="padding:9px 15px;border:1px solid #cbd5e1;border-radius:8px">Batal</button><button type="submit" style="padding:9px 15px;border:0;border-radius:8px;background:#0f172a;color:white">Verifikasi</button></div></form>';
    root.document.body.appendChild(dialog);
    const form = dialog.querySelector('form'), status = dialog.querySelector('[role="status"]');
    const submit = dialog.querySelector('[type="submit"]'), cancel = dialog.querySelector('[data-cancel]');
    let settled = false, busy = false;
    return new Promise(resolve => {
      async function finish(lease) {
        if (settled) return;
        settled = true;
        form.elements.password.value = '';
        dialog.close(); dialog.remove(); pending = false;
        if (!lease) await closeClient(client);
        resolve(lease);
      }
      cancel.onclick = () => { if (!busy) void finish(null); };
      dialog.addEventListener('cancel', event => { event.preventDefault(); if (!busy) void finish(null); });
      form.onsubmit = async event => {
        event.preventDefault(); if (busy || settled) return;
        busy = true; submit.disabled = true; cancel.disabled = true;
        status.textContent = 'Memverifikasi akun dan izin…';
        try {
          const { error } = await client.auth.signInWithPassword({ email: form.elements.email.value.trim(), password: form.elements.password.value });
          form.elements.password.value = '';
          if (error) throw new Error('Email atau password belum dapat diverifikasi.');
          await verify(client, action);
          let closed = false;
          await finish({ client, close: async () => { if (!closed) { closed = true; await closeClient(client); } } });
        } catch (error) {
          form.elements.password.value = '';
          await closeClient(client);
          status.textContent = error.message || 'Verifikasi belum berhasil.';
        } finally { busy = false; submit.disabled = false; cancel.disabled = false; }
      };
      dialog.showModal();
      form.elements.email.focus();
    });
  }
  root.EngineAdminAuth = Object.freeze({ open });
  if (typeof module !== 'undefined' && module.exports) module.exports = { verify, actions, allowedUrl };
})(typeof window !== 'undefined' ? window : globalThis);
