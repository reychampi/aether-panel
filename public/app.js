const socket = io();
let currentPath = '', currentFile = '', allVersions = [];

// --- 1. INFO ---
fetch('/api/info').then(r=>r.json()).then(d => {
    document.getElementById('sidebar-version-text').innerText = 'V' + d.version;
    document.getElementById('header-version').innerText = 'V' + d.version;
});

// --- 2. THEMES ---
function setTheme(mode) { localStorage.setItem('theme', mode); updateThemeUI(mode); }
function updateThemeUI(mode) {
    let apply = mode; if(mode==='auto') apply = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark':'light';
    document.documentElement.setAttribute('data-theme', apply);
    document.querySelectorAll('.theme-btn').forEach(b => b.classList.remove('active'));
    const btn = document.querySelector(`.theme-btn[onclick="setTheme('${mode}')"]`);
    if(btn) btn.classList.add('active');
}
updateThemeUI(localStorage.getItem('theme') || 'dark');

// --- 3. UPDATER ---
checkUpdate(true);
function checkUpdate(isAuto=false) {
    if(!isAuto) Toastify({text:'Buscando actualizaciones...', style:{background:'var(--p)'}}).showToast();
    fetch('/api/update/check').then(r=>r.json()).then(d => {
        if(d.type !== 'none') showUpdateModal(d);
        else if(!isAuto) Toastify({text:'Sistema actualizado', style:{background:'#10b981'}}).showToast();
    }).catch(e => { if(!isAuto) Toastify({text:'Error GitHub', style:{background:'#ef4444'}}).showToast(); });
}
function showUpdateModal(d) {
    const m = document.getElementById('update-modal');
    const t = document.getElementById('update-text');
    const a = document.getElementById('up-actions');
    const ti = document.getElementById('up-title');
    
    if(d.type === 'hard') {
        ti.innerText = "Actualización Mayor";
        t.innerText = `Versión local: ${d.local}\nNueva versión: ${d.remote}\n\nSe requiere reinicio.`;
        a.innerHTML = `<button onclick="doUpdate('hard')" class="btn btn-primary">ACTUALIZAR</button><button onclick="document.getElementById('update-modal').style.display='none'" class="btn btn-ghost">Cancelar</button>`;
        m.style.display='flex';
    } else if(d.type === 'soft') {
        ti.innerText = "Mejora Visual";
        t.innerText = `Cambios visuales detectados.`;
        a.innerHTML = `<button onclick="doUpdate('soft')" class="btn" style="background:#10b981;color:white">APLICAR HOTFIX</button><button onclick="document.getElementById('update-modal').style.display='none'" class="btn btn-ghost">Cancelar</button>`;
        m.style.display='flex';
    }
}
function doUpdate(type) {
    document.getElementById('update-modal').style.display='none';
    fetch('/api/update/perform', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({type})}).then(r=>r.json()).then(d=>{
        if(d.mode === 'soft') { Toastify({text:'Aplicado. Recargando...', style:{background:'#10b981'}}).showToast(); setTimeout(()=>location.reload(), 1500); }
        if(d.mode === 'hard') { Toastify({text:'Reiniciando sistema...', style:{background:'#f59e0b'}}).showToast(); setTimeout(()=>location.reload(), 8000); }
    });
}

// --- 4. TIENDA DE MODS (Añadido V1.3.0) ---
const modsDB = [
    { name: "Jei (Just Enough Items)", url: "https://mediafilez.forgecdn.net/files/5936/206/jei-1.20.1-forge-15.3.0.4.jar", icon: "fa-book" },
    { name: "Iron Chests", url: "https://mediafilez.forgecdn.net/files/4670/664/ironchest-1.20.1-14.4.4.jar", icon: "fa-box" },
    { name: "JourneyMap", url: "https://mediafilez.forgecdn.net/files/5864/381/journeymap-1.20.1-5.9.18-forge.jar", icon: "fa-map" },
    { name: "Nature's Compass", url: "https://mediafilez.forgecdn.net/files/4682/937/NaturesCompass-1.20.1-1.11.2-forge.jar", icon: "fa-compass" },
    { name: "Clumps (Lag Fix)", url: "https://mediafilez.forgecdn.net/files/4603/862/Clumps-forge-1.20.1-12.0.0.3.jar", icon: "fa-users" }
];

function openModStore() {
    const modal = document.getElementById('version-modal');
    const list = document.getElementById('version-list');
    const title = modal.querySelector('h3');
    const loading = document.getElementById('loading-text');
    
    modal.style.display = 'flex';
    list.innerHTML = '';
    title.innerHTML = '<i class="fa-solid fa-puzzle-piece"></i> Tienda de Mods';
    if(loading) loading.style.display = 'none';

    modsDB.forEach(mod => {
        const el = document.createElement('div');
        el.className = 'version-item';
        el.innerHTML = `<div style="display:flex;align-items:center;gap:10px;justify-content:center"><i class="fa-solid ${mod.icon}" style="color:var(--p)"></i> <h4>${mod.name}</h4></div>`;
        el.onclick = () => {
            if(confirm(`¿Instalar ${mod.name}?`)) {
                api('mods/install', { url: mod.url, name: mod.name });
                modal.style.display = 'none';
            }
        };
        list.appendChild(el);
    });
}

// --- 5. CHARTS & OTHERS ---
const createChart = (ctx, color) => new Chart(ctx, { type: 'line', data: { labels: Array(20).fill(''), datasets: [{ data: Array(20).fill(0), borderColor: color, backgroundColor: color+'15', fill: true, tension: 0.4, pointRadius: 0, borderWidth: 2 }] }, options: { responsive: true, maintainAspectRatio: false, animation: { duration: 0 }, scales: { x: { display: false }, y: { min: 0, grid: { display: false } } }, plugins: { legend: { display: false } } } });
const cpuChart = createChart(document.getElementById('cpuChart').getContext('2d'), '#8b5cf6');
const ramChart = createChart(document.getElementById('ramChart').getContext('2d'), '#3b82f6');
setInterval(() => { fetch('/api/stats').then(r => r.json()).then(d => { cpuChart.data.datasets[0].data.shift(); cpuChart.data.datasets[0].data.push(d.cpu); cpuChart.update(); document.getElementById('cpu-val').innerText = d.cpu.toFixed(1) + '%'; ramChart.data.datasets[0].data.shift(); ramChart.data.datasets[0].data.push(d.ram_used); ramChart.options.scales.y.max = d.ram_total; ramChart.update(); document.getElementById('ram-val').innerText = `${d.ram_used.toFixed(0)} MB`; document.getElementById('disk-val').innerText = d.disk_used.toFixed(0) + ' MB'; document.getElementById('disk-fill').style.width = Math.min((d.disk_used/d.disk_total)*100, 100) + '%'; }).catch(()=>{}); }, 1000);

const term = new Terminal({ fontFamily: 'JetBrains Mono', theme: { background: '#00000000' }, fontSize: 13 });
const fitAddon = new FitAddon.FitAddon(); term.loadAddon(fitAddon); term.open(document.getElementById('terminal'));
window.onresize = () => { if(document.getElementById('tab-console').classList.contains('active')) fitAddon.fit(); };
term.onData(d => socket.emit('command', d));
socket.on('console_data', d => term.write(d));
socket.on('logs_history', d => { term.write(d); setTimeout(()=>fitAddon.fit(), 200); });
socket.on('status_change', s => { document.getElementById('status-widget').className = 'status-widget '+s; document.getElementById('status-text').innerText = s; });
socket.on('toast', d => Toastify({text: d.msg, duration: 3000, style: {background: d.type==='error'?'#ef4444':d.type==='success'?'#10b981':'#3b82f6'}}).showToast());

function setTab(t, btn) { document.querySelectorAll('.tab-content').forEach(e => e.classList.remove('active')); document.querySelectorAll('.nav-btn').forEach(e => e.classList.remove('active')); document.getElementById('tab-'+t).classList.add('active'); if(btn) btn.classList.add('active'); if(t==='console') setTimeout(()=>fitAddon.fit(), 100); if(t==='files') loadFileBrowser(''); if(t==='config') loadCfg(); if(t==='backups') loadBackups(); }
function api(ep, body) { return fetch('/api/'+ep, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body) }).then(r => r.json()); }

async function loadVersions(type) {
    const m = document.getElementById('version-modal'); m.style.display='flex'; document.getElementById('version-list').innerHTML=''; 
    const t = m.querySelector('.modal-header h3'); if(t) t.innerHTML = '<i class="fa-solid fa-cloud"></i> Repositorio';
    document.getElementById('loading-text').style.display='inline';
    try { allVersions = await api('nebula/versions', { type }); renderVersions(allVersions); } catch(e) { Toastify({text:'API Error', style:{background:'#ef4444'}}).showToast(); }
    document.getElementById('loading-text').style.display='none';
}
function renderVersions(list) { const g = document.getElementById('version-list'); g.innerHTML=''; list.forEach(v => { const e = document.createElement('div'); e.className='version-item'; e.innerHTML = `<h4>${v.id}</h4><span>${v.type}</span>`; e.onclick = () => installVersion(v); g.appendChild(e); }); }
document.getElementById('version-search').oninput = (e) => { const t = e.target.value.toLowerCase(); renderVersions(allVersions.filter(v => v.id.toLowerCase().includes(t))); };
async function installVersion(v) {
    if(!confirm(`Instalar ${v.type} ${v.id}?`)) return; document.getElementById('version-modal').style.display='none'; let url = '';
    try {
        if(v.type === 'vanilla') { const res = await api('nebula/resolve-vanilla', { url: v.url }); url = res.url; }
        else if (v.type === 'paper') { const r = await fetch(`https://api.papermc.io/v2/projects/paper/versions/${v.id}`); const d = await r.json(); const b = d.builds[d.builds.length-1]; url = `https://api.papermc.io/v2/projects/paper/versions/${v.id}/builds/${b}/downloads/paper-${v.id}-${b}.jar`; }
        else if (v.type === 'fabric') { const r = await fetch('https://meta.fabricmc.net/v2/versions/loader'); const d = await r.json(); url = `https://meta.fabricmc.net/v2/versions/loader/${v.id}/${d[0].version}/1.0.0/server/jar`; }
        else if (v.type === 'forge') { url = `https://maven.minecraftforge.net/net/minecraftforge/forge/${v.id}-${v.id}/forge-${v.id}-${v.id}-universal.jar`; }
        if(url) api('install', { url, filename: 'server.jar' });
    } catch(e) { Toastify({text:'Error Link', style:{background:'#ef4444'}}).showToast(); }
}

function loadFileBrowser(p) { currentPath=p; document.getElementById('file-breadcrumb').innerText='/root'+(p?'/'+p:''); api('files?path='+encodeURIComponent(p)).then(files=>{ const l=document.getElementById('file-list'); l.innerHTML=''; if(p){const b=document.createElement('div');b.className='file-row';b.innerHTML='<span>..</span>';b.onclick=()=>{const a=p.split('/');a.pop();loadFileBrowser(a.join('/'))};l.appendChild(b)} files.forEach(f=>{const e=document.createElement('div');e.className='file-row';e.innerHTML=`<span><i class="fa-solid ${f.isDir?'fa-folder':'fa-file'}" style="color:${f.isDir?'var(--p)':'var(--muted)'}"></i> ${f.name}</span><span>${f.size}</span>`;if(f.isDir)e.onclick=()=>loadFileBrowser((p?p+'/':'')+f.name);else e.onclick=()=>openEditor((p?p+'/':'')+f.name);l.appendChild(e)}) }) }
function uploadFile() { const i=document.createElement('input');i.type='file';i.onchange=(e)=>{const f=new FormData();f.append('file',e.target.files[0]);fetch('/api/files/upload',{method:'POST',body:f}).then(r=>r.json()).then(d=>{if(d.success)loadFileBrowser(currentPath)})};i.click() }
const ed=ace.edit("ace-editor");ed.setTheme("ace/theme/dracula");ed.setOptions({fontSize:"14px"});
function openEditor(f){currentFile=f;api('files/read',{file:f}).then(d=>{if(!d.error){document.getElementById('editor-modal').style.display='flex';ed.setValue(d.content,-1);ed.session.setMode("ace/mode/"+(f.endsWith('.json')?'json':'properties'))}})}
function saveFile(){api('files/save',{file:currentFile,content:ed.getValue()}).then(()=>{document.getElementById('editor-modal').style.display='none'})}
function closeEditor(){document.getElementById('editor-modal').style.display='none'}
function loadBackups(){api('backups').then(b=>{const l=document.getElementById('backup-list');l.innerHTML='';b.forEach(k=>{const e=document.createElement('div');e.className='file-row';e.innerHTML=`<span>${k.name}</span><div><button class="btn btn-sm" onclick="restoreBackup('${k.name}')">Restaurar</button><button class="btn btn-sm stop" onclick="deleteBackup('${k.name}')">X</button></div>`;l.appendChild(e)})})}
function createBackup(){api('backups/create').then(()=>setTimeout(loadBackups,2000))}
function deleteBackup(n){if(confirm('¿Borrar?'))api('backups/delete',{name:n}).then(loadBackups)}
function restoreBackup(n){if(confirm('¿Restaurar?'))api('backups/restore',{name:n})}
function loadCfg(){api('config').then(d=>{const c=document.getElementById('cfg-list');c.innerHTML='';for(const[k,v]of Object.entries(d))c.innerHTML+=`<div><label style="font-size:11px;color:var(--p)">${k}</label><input class="cfg-in" data-k="${k}" value="${v}"></div>`})}
function saveCfg(){const d={};document.querySelectorAll('.cfg-in').forEach(i=>d[i.dataset.k]=i.value);api('config',d)}
