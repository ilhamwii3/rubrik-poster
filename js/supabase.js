const sb = window.supabase.createClient(
  window.PAMERIN_CONFIG.SUPABASE_URL,
  window.PAMERIN_CONFIG.SUPABASE_ANON_KEY
);
window.sb = sb;

window.$ = id => document.getElementById(id);
window.esc = s => { const d = document.createElement('div'); d.textContent = s == null ? '' : String(s); return d.innerHTML; };

window.getSession = async () => {
  const { data } = await sb.auth.getSession();
  return data.session;
};
window.getProfile = async () => {
  const s = await getSession();
  if (!s) return null;
  const { data } = await sb.from('profiles').select('*').eq('id', s.user.id).single();
  return data;
};
window.requireAuth = async (roles = []) => {
  const s = await getSession();
  if (!s) { location.href = '../login.html'; return null; }
  const p = await getProfile();
  if (!p || !p.active) { await sb.auth.signOut(); location.href = '../login.html'; return null; }
  if (roles.length && !roles.includes(p.role)) { location.href = '../login.html'; return null; }
  return { session: s, profile: p };
};
window.logout = async () => {
  await sb.auth.signOut();
  location.href = (document.body.dataset.root || '') + 'login.html';
};
window.toast = (msg, type = 'info') => {
  let el = document.getElementById('toast');
  if (!el) { el = document.createElement('div'); el.id = 'toast'; document.body.appendChild(el); }
  el.textContent = msg;
  el.className = 'toast show ' + type;
  clearTimeout(el._t);
  el._t = setTimeout(() => el.className = 'toast', 3200);
};

// Compress image client-side
window.compressImage = (file, maxW = 1400, quality = 0.85) => new Promise(resolve => {
  const img = new Image();
  img.onload = () => {
    const c = document.createElement('canvas');
    let { width, height } = img;
    if (width > maxW) { height = height * (maxW / width); width = maxW; }
    c.width = width; c.height = height;
    c.getContext('2d').drawImage(img, 0, 0, width, height);
    c.toBlob(b => resolve(b), 'image/jpeg', quality);
  };
  img.src = URL.createObjectURL(file);
});
