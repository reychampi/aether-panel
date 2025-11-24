#!/bin/bash

# ============================================================
# AETHERPANEL NEBULA - V1.1 (LAYOUT FIX + MANUAL UPDATE)
# - Horizontal Action Buttons
# - Manual Update Check in Settings
# - Fixed Sidebar Footer position
# ============================================================
clear
set -e

# Colores
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${PURPLE}🌌 APLICANDO PARCHES VISUALES NEBULA V1.1...${NC}"

# ============================================================
# 1. ACTUALIZACIÓN DE ARCHIVOS WEB
# ============================================================
echo -e "${GREEN}[1/2] ⚡ Actualizando interfaz (Frontend)...${NC}"

# Detenemos momentáneamente para escribir archivos
systemctl stop aetherpanel >/dev/null 2>&1 || true

# --- INDEX.HTML (Ajustes: Botón Update Agregado) ---
cat <<'EOF' > /opt/aetherpanel/public/index.html
<!DOCTYPE html>
<html lang="es" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NEBULA V1.1</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@300;400;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <link rel="stylesheet" type="text/css" href="https://cdn.jsdelivr.net/npm/toastify-js/src/toastify.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css" />
    <script src="/socket.io/socket.io.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script type="text/javascript" src="https://cdn.jsdelivr.net/npm/toastify-js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.32.2/ace.js"></script>
</head>
<body>
    <div id="editor-modal" class="modal-overlay" style="display:none"><div class="modal glass"><div class="modal-header"><h3>Editor</h3><div><button class="btn btn-ghost" onclick="closeEditor()">Cerrar</button><button class="btn btn-primary" onclick="saveFile()">Guardar</button></div></div><div id="ace-editor"></div></div></div>
    <div id="version-modal" class="modal-overlay" style="display:none"><div class="modal glass version-modal"><div class="modal-header"><h3><i class="fa-solid fa-cloud"></i> Repositorio</h3><button class="btn btn-ghost" onclick="document.getElementById('version-modal').style.display='none'"><i class="fa-solid fa-xmark"></i></button></div><div class="mod-search"><input type="text" id="version-search" placeholder="Buscar versión..." class="search-input" autofocus><span id="loading-text" style="display:none;font-size:12px;color:var(--p)"><i class="fa-solid fa-spinner fa-spin"></i> Cargando...</span></div><div id="version-list" class="version-grid"></div></div></div>
    
    <div id="update-modal" class="modal-overlay" style="display:none">
        <div class="modal glass" style="height:auto; max-width:400px; text-align:center; padding:20px;">
            <div style="font-size:3rem; color:var(--p); margin-bottom:10px"><i class="fa-solid fa-bolt"></i></div>
            <h3>Nueva Versión Disponible</h3>
            <p id="update-text" style="color:var(--muted); margin-bottom:20px">Calculando...</p>
            <div style="display:flex; flex-direction:column; gap:10px">
                <button onclick="updateSystem('now')" class="btn btn-primary">ACTUALIZAR AHORA</button>
                <button onclick="updateSystem('stop')" class="btn" style="background:#f59e0b; color:white">AL APAGAR SERVIDOR</button>
                <button onclick="document.getElementById('update-modal').style.display='none'" class="btn btn-ghost">CANCELAR</button>
            </div>
        </div>
    </div>

    <div class="app-layout">
        <aside class="sidebar">
            <div class="brand"><div class="brand-logo"><i class="fa-solid fa-meteor"></i></div><div class="brand-text">V1.1 <span>NEBULA</span></div></div>
            <nav>
                <div class="nav-label">CORE</div>
                <button onclick="setTab('stats', this)" class="nav-btn active"><i class="fa-solid fa-chart-simple"></i> Monitor</button>
                <button onclick="setTab('console', this)" class="nav-btn"><i class="fa-solid fa-terminal"></i> Consola</button>
                <div class="nav-label">DATA</div>
                <button onclick="setTab('files', this)" class="nav-btn"><i class="fa-solid fa-folder-tree"></i> Archivos</button>
                <button onclick="setTab('versions', this)" class="nav-btn"><i class="fa-solid fa-layer-group"></i> Núcleos</button>
                <button onclick="setTab('backups', this)" class="nav-btn"><i class="fa-solid fa-box-archive"></i> Backups</button>
                <button onclick="setTab('config', this)" class="nav-btn"><i class="fa-solid fa-sliders"></i> Ajustes</button>
            </nav>
            <div class="sidebar-footer">
                <div class="theme-switcher">
                    <button onclick="setTheme('light')" class="theme-btn" title="Claro"><i class="fa-solid fa-sun"></i></button>
                    <button onclick="setTheme('dark')" class="theme-btn active" title="Oscuro"><i class="fa-solid fa-moon"></i></button>
                    <button onclick="setTheme('auto')" class="theme-btn" title="Sistema"><i class="fa-solid fa-desktop"></i></button>
                </div>
                <div class="status-widget OFFLINE" id="status-widget"><div class="status-indicator"></div><span id="status-text">OFFLINE</span></div>
            </div>
        </aside>
        <main>
            <header>
                <div class="server-info"><h1>Nebula Dashboard</h1><div class="badges"><span class="badge badge-primary">V1.1</span><span class="badge">Stable</span></div></div>
                <div class="actions">
                    <button onclick="api('power/start')" class="btn-control start" title="Iniciar"><i class="fa-solid fa-play"></i></button>
                    <button onclick="api('power/restart')" class="btn-control restart" title="Reiniciar"><i class="fa-solid fa-rotate-right"></i></button>
                    <button onclick="api('power/stop')" class="btn-control stop" title="Detener"><i class="fa-solid fa-power-off"></i></button>
                    <button onclick="api('power/kill')" class="btn-control kill" title="Forzar Apagado"><i class="fa-solid fa-skull-crossbones"></i></button>
                </div>
            </header>

            <div id="tab-stats" class="tab-content active">
                <div class="stats-grid">
                    <div class="card glass"><div class="card-header"><h3>CPU</h3><span class="stat-value" id="cpu-val">0%</span></div><div class="chart-container"><canvas id="cpuChart"></canvas></div></div>
                    <div class="card glass"><div class="card-header"><h3>RAM</h3><span class="stat-value" id="ram-val">0 MB</span></div><div class="chart-container"><canvas id="ramChart"></canvas></div></div>
                    <div class="card glass"><div class="card-header"><h3>Disco</h3><span class="stat-value" id="disk-val">...</span></div><div class="disk-bar"><div class="disk-fill" id="disk-fill"></div></div></div>
                </div>
            </div>
            
            <div id="tab-console" class="tab-content"><div class="console-box glass"><div id="terminal"></div></div></div>
            <div id="tab-files" class="tab-content"><div class="card glass full"><div class="card-header"><div class="breadcrumb" id="file-breadcrumb">/root</div><div><button onclick="loadFileBrowser(currentPath)" class="btn btn-ghost"><i class="fa-solid fa-rotate"></i></button><button onclick="uploadFile()" class="btn btn-primary"><i class="fa-solid fa-upload"></i></button></div></div><div id="file-list" class="file-list"></div></div></div>
            
            <div id="tab-versions" class="tab-content">
                <h2 class="tab-title">Núcleos Disponibles</h2>
                <div class="versions-container">
                    <div class="version-card glass" onclick="loadVersions('vanilla')"><div class="v-icon" style="background:#27ae60"><i class="fa-solid fa-cube"></i></div><div class="v-info"><h3>Vanilla</h3><p>Oficial</p></div></div>
                    <div class="version-card glass" onclick="loadVersions('paper')"><div class="v-icon" style="background:#2980b9"><i class="fa-solid fa-paper-plane"></i></div><div class="v-info"><h3>Paper</h3><p>Optimizado</p></div></div>
                    <div class="version-card glass" onclick="loadVersions('fabric')"><div class="v-icon" style="background:#f39c12"><i class="fa-solid fa-scroll"></i></div><div class="v-info"><h3>Fabric</h3><p>Mods</p></div></div>
                    <div class="version-card glass" onclick="loadVersions('forge')"><div class="v-icon" style="background:#c0392b"><i class="fa-solid fa-hammer"></i></div><div class="v-info"><h3>Forge</h3><p>Ilimitado</p></div></div>
                </div>
            </div>
            
            <div id="tab-backups" class="tab-content"><div class="card glass full"><div class="card-header"><h3>Backups</h3><button onclick="createBackup()" class="btn btn-primary">Crear</button></div><div id="backup-list" class="file-list"></div></div></div>
            
            <div id="tab-config" class="tab-content">
                <div class="card glass full">
                    <div class="card-header">
                        <h3>Configuración del Servidor</h3>
                        <button onclick="saveCfg()" class="btn btn-primary"><i class="fa-solid fa-floppy-disk"></i> Guardar</button>
                    </div>
                    <div id="cfg-list" class="cfg-grid"></div>
                    
                    <div style="padding: 20px; border-top: 1px solid var(--border); margin-top: 20px;">
                        <h3 style="color: var(--muted); font-size: 0.9rem; margin-bottom: 15px;">MANTENIMIENTO DEL SISTEMA</h3>
                        <button onclick="manualUpdateCheck()" class="btn" style="background: var(--glass); border: 1px solid var(--border); width: 100%; justify-content: center;">
                            <i class="fa-solid fa-rotate"></i> BUSCAR ACTUALIZACIONES DE NEBULA
                        </button>
                    </div>
                </div>
            </div>
        </main>
    </div>
    <script src="app.js"></script>
</body>
</html>
EOF

# --- STYLE.CSS (Fixes: Footer Position & Horizontal Actions) ---
cat <<'EOF' > /opt/aetherpanel/public/style.css
:root { --bg: #0f0f13; --sb: #050507; --card-bg: #121214; --glass: rgba(255,255,255,0.03); --border: rgba(255,255,255,0.06); --p: #8b5cf6; --txt: #e4e4e7; --muted: #71717a; --radius: 12px; --console-bg: #000000; }
[data-theme="light"] { --bg: #f8fafc; --sb: #ffffff; --card-bg: #ffffff; --glass: rgba(0,0,0,0.02); --border: rgba(0,0,0,0.08); --p: #6366f1; --txt: #0f172a; --muted: #64748b; --console-bg: #1e293b; }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Manrope', sans-serif; background: var(--bg); color: var(--txt); height: 100vh; overflow: hidden; transition: background 0.3s, color 0.3s; }
.glass { background: var(--glass); backdrop-filter: blur(12px); border: 1px solid var(--border); border-radius: var(--radius); background-color: var(--card-bg); }

.app-layout { display: flex; height: 100%; }

/* SIDEBAR FIXED LAYOUT */
.sidebar { 
    width: 260px; 
    background: var(--sb); 
    border-right: 1px solid var(--border); 
    padding: 24px; 
    display: flex; 
    flex-direction: column; 
    transition: background 0.3s;
    height: 100vh; /* Asegurar altura completa */
    justify-content: space-between; /* Empujar footer abajo */
}

.brand { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; font-weight: 800; font-size: 1.4rem; flex-shrink: 0; } 
.brand span { color: var(--p); } .brand-logo { color: var(--p); font-size: 1.2rem; }

nav {
    flex: 1; /* Ocupar espacio disponible */
    overflow-y: auto; /* Scroll si hay muchos items */
    margin-bottom: 20px;
}

.sidebar-footer {
    margin-top: auto; /* Redundancia para seguridad */
    flex-shrink: 0; /* No encoger */
}

.nav-label { font-size: 0.7rem; color: var(--muted); font-weight: 700; margin: 20px 0 8px 12px; letter-spacing: 1px; }
.nav-btn { width: 100%; background: transparent; border: none; padding: 12px; color: var(--muted); text-align: left; border-radius: 8px; cursor: pointer; font-family: inherit; font-weight: 500; display: flex; align-items: center; gap: 12px; transition: 0.2s; }
.nav-btn:hover { background: var(--glass); color: var(--txt); } .nav-btn.active { background: rgba(139,92,246,0.1); color: var(--p); font-weight: 700; }

.theme-switcher { display: flex; background: var(--glass); padding: 4px; border-radius: 8px; margin-bottom: 15px; border: 1px solid var(--border); }
.theme-btn { flex: 1; background: transparent; border: none; color: var(--muted); padding: 6px; border-radius: 6px; cursor: pointer; transition: 0.2s; } .theme-btn:hover { color: var(--txt); } .theme-btn.active { background: var(--bg); color: var(--p); box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
.status-widget { background: var(--glass); padding: 12px; border-radius: 8px; border: 1px solid var(--border); display: flex; align-items: center; gap: 12px; }
.status-indicator { width: 8px; height: 8px; border-radius: 50%; background: #ef4444; } .ONLINE .status-indicator { background: #10b981; box-shadow: 0 0 10px rgba(16,185,129,0.4); }

main { flex: 1; padding: 32px 40px; display: flex; flex-direction: column; overflow-y: auto; }

/* HEADER FIXED - HORIZONTAL ACTIONS */
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
.actions { 
    display: flex; 
    gap: 10px; 
    align-items: center;
    flex-direction: row !important; /* FORZAR HORIZONTAL */
}

.badges { display: flex; gap: 8px; margin-top: 8px; } .badge { font-size: 0.7rem; background: var(--glass); padding: 4px 10px; border-radius: 20px; border: 1px solid var(--border); font-weight: 600; color: var(--muted); }
.btn-control { width: 44px; height: 44px; border-radius: 12px; border: none; color: white; cursor: pointer; font-size: 1.1rem; transition: 0.2s; display: flex; align-items: center; justify-content: center; flex-shrink: 0; } .btn-control:hover { transform: scale(1.05); }
.start { background: linear-gradient(135deg, #10b981, #059669); } .restart { background: linear-gradient(135deg, #f59e0b, #d97706); } .stop { background: linear-gradient(135deg, #ef4444, #dc2626); } .kill { background: #27272a; }

.tab-content { display: none; animation: fadeUp 0.3s ease; } .tab-content.active { display: block; } @keyframes fadeUp { from{opacity:0; transform:translateY(10px)} to{opacity:1; transform:translateY(0)} }
.stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 24px; }
.card { padding: 24px; display: flex; flex-direction: column; background-color: var(--card-bg); } .card.full { min-height: 400px; }
.card-header { display: flex; justify-content: space-between; margin-bottom: 10px; align-items: center; } .card-header h3 { font-size: 0.9rem; color: var(--muted); font-weight: 600; } .stat-value { font-family: 'JetBrains Mono'; font-weight: 700; font-size: 1.2rem; }
.chart-container { height: 140px; position: relative; width: 100%; }
.console-box { height: calc(100vh - 220px); background: var(--console-bg); border-radius: var(--radius); border: 1px solid var(--border); padding: 16px; overflow: hidden; } #terminal { height: 100%; }
.file-row { display: flex; justify-content: space-between; padding: 14px 16px; border-bottom: 1px solid var(--border); cursor: pointer; font-family: 'JetBrains Mono'; font-size: 0.9rem; transition: 0.1s; color: var(--txt); } .file-row:hover { background: rgba(128,128,128,0.05); }
.disk-bar { height: 6px; background: rgba(128,128,128,0.2); border-radius: 3px; overflow: hidden; margin-top: 16px; } .disk-fill { height: 100%; background: var(--p); width: 0%; transition: 0.5s; }
.versions-container { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 20px; margin-top: 20px; }
.version-card { display: flex; align-items: center; gap: 16px; padding: 24px; cursor: pointer; transition: 0.2s; border: 1px solid var(--border); } .version-card:hover { border-color: var(--p); transform: translateY(-3px); }
.v-icon { width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; color: white; font-size: 1.4rem; }
.v-info h3 { font-size: 1.1rem; margin-bottom: 4px; } .v-info p { font-size: 0.8rem; color: var(--muted); }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.6); backdrop-filter: blur(5px); z-index: 100; display: flex; justify-content: center; align-items: center; }
.modal { width: 80%; max-width: 900px; height: 80vh; background: var(--card-bg); border: 1px solid var(--border); border-radius: 20px; display: flex; flex-direction: column; }
.modal-header { padding: 20px 24px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
#ace-editor { flex: 1; border-bottom-left-radius: 20px; border-bottom-right-radius: 20px; }
.version-grid { padding: 24px; overflow-y: auto; display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 12px; flex: 1; }
.version-item { background: var(--glass); padding: 16px; border-radius: 10px; text-align: center; cursor: pointer; border: 1px solid var(--border); transition: 0.1s; } .version-item:hover { border-color: var(--p); }
.search-input { width: 100%; padding: 14px; background: var(--glass); border: 1px solid var(--border); color: var(--txt); border-radius: 10px; font-size: 1rem; outline: none; }
.mod-search { padding: 20px 24px; border-bottom: 1px solid var(--border); display: flex; gap: 16px; align-items: center; }
.btn { border: none; padding: 8px 18px; border-radius: 8px; cursor: pointer; font-weight: 600; font-family: inherit; font-size: 0.9rem; transition: 0.2s; } .btn-primary { background: var(--p); color: white; } .btn-ghost { background: transparent; color: var(--muted); }
.cfg-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; padding: 24px; overflow-y: auto; }
.cfg-in { width: 100%; background: var(--glass); border: 1px solid var(--border); padding: 10px; color: var(--txt); border-radius: 6px; font-family: 'JetBrains Mono'; }
</style>
EOF

# --- APP.JS (Con función manualUpdateCheck) ---
cat <<'EOF' > /opt/aetherpanel/public/app.js
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
EOF

# ============================================================
# 2. REINICIAR
# ============================================================
echo -e "${GREEN}[2/2] 🔄 Aplicando cambios...${NC}"
systemctl restart aetherpanel
IP=$(hostname -I | awk '{print $1}')
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}🌌 NEBULA V1.1 LISTO: http://${IP}:3000${NC}"
echo -e "${CYAN}==========================================${NC}"