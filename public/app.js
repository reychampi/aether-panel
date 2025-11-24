const socket = io();
let currentPath = '', currentFile = '', allVersions = [];

// THEMES
function setTheme(mode) { localStorage.setItem('theme', mode); updateThemeUI(mode); }
function updateThemeUI(mode) {
    let apply = mode; if(mode==='auto') apply = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark':'light';
    document.documentElement.setAttribute('data-theme', apply);
    document.querySelectorAll('.theme-btn').forEach(b => b.classList.remove('active'));
    const btn = document.querySelector(`.theme-btn[onclick="setTheme('${mode}')"]`);
    if(btn) btn.classList.add('active');
}
updateThemeUI(localStorage.getItem('theme') || 'dark');

// UPDATER (Manual Trigger)
function manualUpdateCheck() {
    Toastify({text:'Buscando actualizaciones...', style:{background: 'var(--p)'}}).showToast();
    fetch('/api/update/check').then(r=>r.json()).then(d=>{
        if(d.update) {
            document.getElementById('update-text').innerText = `Versión instalada: ${d.local}\nNueva versión: ${d.remote}`;
            document.getElementById('update-modal').style.display='flex';
        } else {
            Toastify({text:'Sistema actualizado (V1.1)', style:{background:'#10b981'}}).showToast();
        }
    }).catch(()=>Toastify({text:'Error conectando con GitHub', style:{background:'#ef4444'}}).showToast());
}

// UPDATER (Auto Check Silent)
fetch('/api/update/check').then(r=>r.json()).then(d=>{
    if(d.update) {
        document.getElementById('update-text').innerText = `Versión instalada: ${d.local}\nNueva versión: ${d.remote}`;
        document.getElementById('update-modal').style.display='flex';
    }
});

function updateSystem(when) {
    fetch('/api/update/schedule', {
        method: 'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({when})
    }).then(r=>r.json()).then(d=>{
        document.getElementById('update-modal').style.display='none';
        Toastify({text: d.msg, duration:5000, style:{background:'#f59e0b'}}).showToast();
    });
}

// CHARTS
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
    const m = document.getElementById('version-modal'); m.style.display='flex'; document.getElementById('version-list').innerHTML=''; document.getElementById('loading-text').style.display='inline';
    try { allVersions = await api('nebula/versions', { type }); renderVersions(allVersions); } catch(e) { Toastify({text:'API Error', style:{background:'#ef4444'}}).showToast(); }
    document.getElementById('loading-text').style.display='none';
}
function renderVersions(list) { const g = document.getElementById('version-list'); g.innerHTML=''; list.forEach(v => { const e = document.createElement('div'); e.className='version-item'; e.innerHTML = `<h4>${v.id}</h4><span>${v.type}</span>`; e.onclick = () => installVersion(v); g.appendChild(e); }); }
document.getElementById('version-search').oninput = (e) => { const t = e.target.value.toLowerCase(); renderVersions(allVersions.filter(v => v.id.toLowerCase().includes(t))); };
async function installVersion(v) {
    if(!confirm(`Instalar ${v.type} ${v.id}?`)) return; document.getElementById('version-modal').style.display='none'; let url = '';
    try {
        if(v.type === 'vanilla') { const res = await api('nebula/resolve-vanilla', { url: v.url }); url = res.url; }
        else if (v.type === 'paper') { const r = await fetch(`https://api.papermc.io/v2/projects/paper/versions/${v.id}`); const d = await r.json(); url = `https://api.papermc.io/v2/projects/paper/versions/${v.id}/builds/${d.builds[d.builds.length-1]}/downloads/paper-${v.id}-${d.builds[d.builds.length-1]}.jar`; }
        else if (v.type === 'fabric') { const r = await fetch('https://meta.fabricmc.net/v2/versions/loader'); const d = await r.json(); url = `https://meta.fabricmc.net/v2/versions/loader/${v.id}/${d[0].version}/1.0.0/server/jar`; }
        else if (v.type === 'forge') { url = `https://maven.minecraftforge.net/net/minecraftforge/forge/${v.id}-${v.id}/forge-${v.id}-${v.id}-universal.jar`; Toastify({text:'Intentando descarga directa...', style:{background:'#f39c12'}}).showToast(); }
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
