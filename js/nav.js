function renderHeader(root = '') {
  return `<header class="site-header">
    <div class="header-inner">
      <a href="${root}index.html" class="brand"><span class="brand-dot"></span>Rubrik Poster</a>
      <button class="nav-toggle" id="navToggle" aria-label="Menu"><span></span><span></span><span></span></button>
      <nav class="nav" id="navMenu">
        <a href="${root}index.html">Beranda</a>
        <a href="${root}gallery.html">Galeri</a>
        <a href="${root}ranking.html">Ranking</a>
        <a href="${root}scan.html">Scan</a>
        <a href="${root}submit.html">Upload Karya</a>
        <span id="navAuth"></span>
      </nav>
    </div>
  </header>`;
}

async function initHeader() {
  const root = document.body.dataset.root || '';
  const placeholder = document.getElementById('header');
  if (placeholder) placeholder.outerHTML = renderHeader(root);
  const toggle = document.getElementById('navToggle');
  if (toggle) toggle.onclick = () => {
    toggle.classList.toggle('open');
    document.getElementById('navMenu').classList.toggle('open');
  };
  const navAuth = document.getElementById('navAuth');
  if (!navAuth) return;
  const s = await getSession();
  if (!s) {
    navAuth.innerHTML = `<a href="${root}login.html">Login</a>`;
    return;
  }
  const p = await getProfile();
  if (!p || !p.active) {
    navAuth.innerHTML = `<a href="#" onclick="logout();return false">Logout</a>`;
    return;
  }
  if (p.role === 'admin') {
    navAuth.innerHTML = `
      <a href="${root}admin/dashboard.html">Dashboard</a>
      <a href="#" onclick="logout();return false">Logout</a>`;
  } else {
    navAuth.innerHTML = `
      <a href="${root}judge/dashboard.html">Dashboard Penilai</a>
      <a href="#" onclick="logout();return false">Logout</a>`;
  }
}

document.addEventListener('DOMContentLoaded', initHeader);
