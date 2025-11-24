#!/bin/bash

# ============================================================
# AETHERPANEL - V5.7 FINAL STABLE
# Corrección definitiva de librerías (os-utils 0.0.14)
# ============================================================
clear
set -e

# Colores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}🚀 INICIANDO INSTALACIÓN V5.7 (FINAL)...${NC}"

# ============================================================
# 1. LIMPIEZA Y PREPARACIÓN
# ============================================================
echo -e "${GREEN}[1/6] 🧹 Limpiando sistema...${NC}"

# Detener todo
systemctl stop aetherpanel >/dev/null 2>&1 || true
pkill -f node >/dev/null 2>&1 || true
pkill -f java >/dev/null 2>&1 || true

# Borrar carpeta completa para asegurar que no queda el archivo viejo
rm -rf /opt/aetherpanel
mkdir -p /opt/aetherpanel/{servers/default,public}

# ============================================================
# 2. GENERACIÓN DE ARCHIVOS
# ============================================================
echo -e "${GREEN}[2/6] 📝 Escribiendo archivos de configuración...${NC}"

# --- PACKAGE.JSON (CORREGIDO: 0.0.14) ---
cat <<EOF > /opt/aetherpanel/package.json
{
  "name": "aetherpanel-stable",
  "version": "5.7.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "cors": "^2.8.5",
    "axios": "^1.6.2",
    "os-utils": "^0.0.14",
    "node-os-utils": "^1.3.7"
  }
}
EOF

# --- SERVER.JS ---
cat <<EOF > /opt/aetherpanel/server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');
const MCManager = require('./mc_manager');
const os = require('os');
const osUtils = require('os-utils');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

const mcServer = new MCManager(io);

app.get('/api/stats', (req, res) => {
    osUtils.cpuUsage((cpuPercent) => {
        res.json({
            cpu: (cpuPercent * 100).toFixed(1),
            ram_total: (os.totalmem() / 1024 / 1024 / 1024).toFixed(2),
            ram_used: ((os.totalmem() - os.freemem()) / 1024 / 1024 / 1024).toFixed(2)
        });
    });
});

app.get('/api/status', (req, res) => res.json(mcServer.getStatus()));
app.post('/api/power/:action', async (req, res) => {
    try {
        const act = req.params.action;
        if(mcServer[act]) await mcServer[act]();
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/config', (req, res) => res.json(mcServer.readProperties()));
app.post('/api/config', (req, res) => { mcServer.writeProperties(req.body); res.json({success:true}); });

app.post('/api/install', async (req, res) => {
    try {
        await mcServer.installJar(req.body.url, req.body.filename);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/files', (req, res) => {
    const dir = path.join(__dirname, 'servers', 'default');
    fs.readdir(dir, { withFileTypes: true }, (err, files) => {
        if(err) return res.json([]);
        const result = files.map(f => ({
            name: f.name,
            isDir: f.isDirectory(),
            size: f.isDirectory() ? '-' : (fs.statSync(path.join(dir, f.name)).size / 1024).toFixed(1) + ' KB'
        }));
        result.sort((a,b) => (a.isDir === b.isDir) ? 0 : a.isDir ? -1 : 1);
        res.json(result);
    });
});

app.post('/api/files/read', (req, res) => {
    const p = path.join(__dirname, 'servers', 'default', req.body.file);
    if(fs.existsSync(p)) res.json({ content: fs.readFileSync(p, 'utf8') });
    else res.status(404).json({ error: 'File not found' });
});

app.post('/api/files/save', (req, res) => {
    const p = path.join(__dirname, 'servers', 'default', req.body.file);
    fs.writeFileSync(p, req.body.content);
    res.json({ success: true });
});

io.on('connection', (socket) => {
    socket.emit('logs_history', mcServer.getRecentLogs());
    socket.emit('status_change', mcServer.status);
    socket.on('command', (cmd) => mcServer.sendCommand(cmd));
});

server.listen(3000, () => console.log('AetherPanel V5.7 running on port 3000'));
EOF

# --- MC_MANAGER.JS ---
cat <<EOF > /opt/aetherpanel/mc_manager.js
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const axios = require('axios');

class MCManager {
    constructor(io) {
        this.io = io;
        this.process = null;
        this.serverPath = path.join(__dirname, 'servers', 'default');
        if (!fs.existsSync(this.serverPath)) fs.mkdirSync(this.serverPath, { recursive: true });
        this.status = 'OFFLINE';
        this.logs = [];
        this.ram = '4G';
    }

    log(msg) {
        this.logs.push(msg);
        if (this.logs.length > 2000) this.logs.shift();
        this.io.emit('console_data', msg); 
    }

    getStatus() { return { status: this.status, ram: this.ram }; }
    getRecentLogs() { return this.logs.join(''); }

    async start() {
        if (this.status !== 'OFFLINE') return;
        const eula = path.join(this.serverPath, 'eula.txt');
        fs.writeFileSync(eula, 'eula=true');
        const jar = fs.readdirSync(this.serverPath).find(f => f.endsWith('.jar'));
        if (!jar) { 
            this.io.emit('toast', { type: 'error', msg: 'No server.jar found.' });
            return; 
        }

        this.status = 'STARTING';
        this.io.emit('status_change', this.status);
        this.log('\r\n\x1b[36m>>> Starting Aether Server (V5.7)...\x1b[0m\r\n');

        const args = ['-Xmx'+this.ram, '-Xms'+this.ram, '-jar', jar, 'nogui'];
        this.process = spawn('java', args, { cwd: this.serverPath });

        this.process.stdout.on('data', d => {
            const s = d.toString();
            this.log(s);
            if(s.includes('Done')) { 
                this.status = 'ONLINE'; 
                this.io.emit('status_change', this.status); 
                this.io.emit('toast', { type: 'success', msg: 'Server Online' });
            }
        });
        this.process.stderr.on('data', d => this.log(d.toString()));
        this.process.on('close', c => {
            this.status = 'OFFLINE'; 
            this.process = null; 
            this.io.emit('status_change', this.status);
            this.log('\r\nStopped.\r\n');
        });
    }

    async stop() {
        if (this.process && this.status === 'ONLINE') {
            this.status = 'STOPPING';
            this.io.emit('status_change', this.status);
            this.process.stdin.write('stop\n');
        }
    }
    
    async restart() { await this.stop(); setTimeout(() => this.start(), 5000); }
    async kill() { if(this.process) { this.process.kill('SIGKILL'); this.status='OFFLINE'; this.io.emit('status_change','OFFLINE'); } }
    sendCommand(c) { if(this.process) this.process.stdin.write(c+'\n'); }

    async installJar(url, filename) {
        this.io.emit('toast', {type:'info', msg:'Downloading...'});
        const files = fs.readdirSync(this.serverPath);
        for (const file of files) if (file.endsWith('.jar')) fs.unlinkSync(path.join(this.serverPath, file));

        const w = fs.createWriteStream(path.join(this.serverPath, filename));
        const r = await axios({url, method:'GET', responseType:'stream'});
        r.data.pipe(w);
        return new Promise((res, rej) => {
            w.on('finish', () => { this.io.emit('toast', {type:'success', msg:'Installed.'}); res(); });
            w.on('error', (e) => rej(e));
        });
    }

    readProperties() {
        try {
            const c = fs.readFileSync(path.join(this.serverPath, 'server.properties'), 'utf8');
            const p = {};
            c.split('\n').forEach(l => { if(l && !l.startsWith('#')) { const [k,v] = l.split('='); if(k) p[k.trim()]=v?v.trim():''; } });
            return p;
        } catch { return {}; }
    }

    writeProperties(p) {
        let c = '#Gen by AetherPanel\n';
        for(const [k,v] of Object.entries(p)) c += \`\${k}=\${v}\n\`;
        fs.writeFileSync(path.join(this.serverPath, 'server.properties'), c);
    }
}
module.exports = MCManager;
EOF

# --- INDEX.HTML ---
cat <<EOF > /opt/aetherpanel/public/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AetherPanel Stable</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@300;400;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
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
    <div id="editor-modal" class="modal-overlay" style="display:none">
        <div class="modal glass">
            <div class="modal-header">
                <h3><i class="fa-solid fa-file-code"></i> Editor</h3>
                <div>
                    <button class="btn btn-ghost" onclick="closeEditor()">Cancelar</button>
                    <button class="btn btn-primary" onclick="saveFile()">Guardar</button>
                </div>
            </div>
            <div id="ace-editor" style="height:400px; width:100%"></div>
        </div>
    </div>
    <div class="app-layout">
        <aside class="sidebar">
            <div class="brand">
                <div class="brand-logo"><i class="fa-solid fa-gem"></i></div>
                <div class="brand-text">AETHER<span>STABLE</span></div>
            </div>
            <nav>
                <div class="nav-label">CONTROL</div>
                <button onclick="setTab('stats')" class="nav-btn active"><i class="fa-solid fa-chart-pie"></i> Monitor</button>
                <button onclick="setTab('console')" class="nav-btn"><i class="fa-solid fa-terminal"></i> Terminal</button>
                <div class="nav-label">SERVER</div>
                <button onclick="setTab('files')" class="nav-btn"><i class="fa-solid fa-folder"></i> Archivos</button>
                <button onclick="setTab('versions')" class="nav-btn"><i class="fa-solid fa-download"></i> Versiones</button>
                <button onclick="setTab('config')" class="nav-btn"><i class="fa-solid fa-gears"></i> Ajustes</button>
            </nav>
            <div class="status-widget OFFLINE" id="status-widget">
                <div class="status-indicator"></div>
                <span id="status-text">OFFLINE</span>
            </div>
        </aside>
        <main>
            <header>
                <div class="server-info"><h1>Minecraft Server</h1><span class="badge">V5.7 Final</span></div>
                <div class="actions">
                    <button onclick="api('power/start')" class="btn-control start"><i class="fa-solid fa-play"></i></button>
                    <button onclick="api('power/restart')" class="btn-control restart"><i class="fa-solid fa-rotate-right"></i></button>
                    <button onclick="api('power/stop')" class="btn-control stop"><i class="fa-solid fa-stop"></i></button>
                    <button onclick="api('power/kill')" class="btn-control kill"><i class="fa-solid fa-skull"></i></button>
                </div>
            </header>
            <div id="tab-stats" class="tab-content active">
                <div class="grid-2">
                    <div class="card glass"><h3><i class="fa-solid fa-microchip"></i> CPU</h3><canvas id="cpuChart"></canvas></div>
                    <div class="card glass"><h3><i class="fa-solid fa-memory"></i> RAM</h3><canvas id="ramChart"></canvas></div>
                </div>
            </div>
            <div id="tab-console" class="tab-content"><div class="console-box glass"><div id="terminal"></div></div></div>
            <div id="tab-files" class="tab-content"><div class="card glass full"><div class="card-header"><h3>/home/container</h3><button onclick="loadFileBrowser()" class="btn btn-sm"><i class="fa-solid fa-rotate"></i></button></div><div id="file-list" class="file-list"></div></div></div>
            <div id="tab-versions" class="tab-content"><div class="grid-3">
                <div class="v-card glass" onclick="install('paper', '1.20.4')"><i class="fa-solid fa-paper-plane" style="color:#6366f1"></i><h4>Paper 1.20.4</h4></div>
                <div class="v-card glass" onclick="install('vanilla', '1.20.4')"><i class="fa-solid fa-cube" style="color:#10b981"></i><h4>Vanilla 1.20.4</h4></div>
                <div class="v-card glass" onclick="install('forge', '1.20.1')"><i class="fa-solid fa-wrench" style="color:#f59e0b"></i><h4>Forge 1.20.1</h4></div>
            </div></div>
            <div id="tab-config" class="tab-content"><div class="card glass full"><div class="card-header"><h3>Server Properties</h3><button onclick="saveCfg()" class="btn btn-primary">Guardar</button></div><div id="cfg-list" class="cfg-grid"></div></div></div>
        </main>
    </div>
    <script src="app.js"></script>
</body>
</html>
EOF

# --- CSS ---
cat <<EOF > /opt/aetherpanel/public/style.css
:root { --bg: #09090b; --sidebar: #0f0f11; --glass: rgba(255, 255, 255, 0.03); --border: rgba(255, 255, 255, 0.08); --primary: #6366f1; --success: #10b981; --danger: #ef4444; --text: #e4e4e7; --text-mute: #a1a1aa; --radius: 12px; }
* { box-sizing: border-box; } body { margin: 0; background: var(--bg); color: var(--text); font-family: 'Manrope', sans-serif; overflow: hidden; height: 100vh; }
.app-layout { display: flex; height: 100%; }
.sidebar { width: 260px; background: var(--sidebar); border-right: 1px solid var(--border); padding: 24px; display: flex; flex-direction: column; }
.brand { display: flex; align-items: center; gap: 12px; margin-bottom: 40px; }
.brand-logo { width: 36px; height: 36px; background: var(--primary); border-radius: 8px; display: flex; align-items: center; justify-content: center; color: white; box-shadow: 0 0 15px rgba(99,102,241,0.3); }
.brand-text { font-weight: 700; font-size: 16px; } .brand-text span { color: var(--primary); font-size: 11px; margin-left: 5px; }
.nav-label { font-size: 10px; color: var(--text-mute); font-weight: 700; margin: 20px 0 10px 5px; letter-spacing: 1px; }
.nav-btn { width: 100%; text-align: left; background: transparent; border: none; padding: 12px 16px; border-radius: 8px; color: var(--text-mute); font-family: inherit; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 12px; transition: 0.2s; }
.nav-btn:hover { background: rgba(255,255,255,0.03); color: white; } .nav-btn.active { background: rgba(99,102,241,0.1); color: var(--primary); border-left: 3px solid var(--primary); }
.status-widget { margin-top: auto; padding: 15px; background: rgba(0,0,0,0.3); border-radius: var(--radius); display: flex; align-items: center; gap: 10px; border: 1px solid var(--border); }
.status-indicator { width: 8px; height: 8px; border-radius: 50%; background: #555; }
.ONLINE .status-indicator { background: var(--success); box-shadow: 0 0 8px var(--success); } .OFFLINE .status-indicator { background: var(--danger); } .STARTING .status-indicator { background: #eab308; }
main { flex: 1; padding: 30px; display: flex; flex-direction: column; overflow: hidden; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
.server-info h1 { margin: 0; font-size: 20px; } .badge { font-size: 11px; background: rgba(255,255,255,0.1); padding: 4px 8px; border-radius: 4px; color: var(--text-mute); }
.actions { display: flex; gap: 10px; }
.btn-control { width: 40px; height: 40px; border-radius: 10px; border: none; color: white; cursor: pointer; transition: 0.2s; font-size: 16px; }
.btn-control:hover { transform: translateY(-2px); } .start { background: var(--success); } .restart { background: #f59e0b; } .stop { background: var(--danger); } .kill { background: #3f3f46; }
.tab-content { display: none; height: 100%; flex-direction: column; } .tab-content.active { display: flex; }
.glass { background: var(--glass); border: 1px solid var(--border); backdrop-filter: blur(10px); border-radius: var(--radius); }
.card { padding: 20px; display: flex; flex-direction: column; } .card.full { flex: 1; overflow: hidden; }
.card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; border-bottom: 1px solid var(--border); padding-bottom: 10px; } .card h3 { margin: 0; font-size: 14px; color: var(--text-mute); }
.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; height: 100%; } .grid-3 { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 20px; }
.console-box { flex: 1; padding: 10px; background: #0c0c0e; border-radius: var(--radius); border: 1px solid var(--border); overflow: hidden; } #terminal { height: 100%; }
.file-list { overflow-y: auto; flex: 1; }
.file-row { display: flex; justify-content: space-between; padding: 12px; border-bottom: 1px solid rgba(255,255,255,0.02); cursor: pointer; transition: 0.2s; font-family: 'JetBrains Mono', monospace; font-size: 13px; } .file-row:hover { background: rgba(255,255,255,0.05); }
.v-card { padding: 30px; text-align: center; cursor: pointer; transition: 0.3s; } .v-card:hover { border-color: var(--primary); background: rgba(99,102,241,0.05); transform: translateY(-5px); } .v-card i { font-size: 32px; margin-bottom: 15px; }
.cfg-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 15px; overflow-y: auto; padding-right: 5px; }
.cfg-item { display: flex; flex-direction: column; background: rgba(0,0,0,0.2); padding: 10px; border-radius: 8px; border: 1px solid var(--border); } .cfg-item label { font-size: 10px; color: var(--primary); margin-bottom: 5px; } .cfg-item input { background: transparent; border: none; color: white; border-bottom: 1px solid rgba(255,255,255,0.1); font-family: 'JetBrains Mono'; font-size: 13px; }
.btn { padding: 8px 16px; border-radius: 8px; border: none; font-weight: 600; cursor: pointer; font-family: inherit; } .btn-primary { background: var(--primary); color: white; } .btn-ghost { background: transparent; color: var(--text-mute); }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.6); display: flex; justify-content: center; align-items: center; z-index: 100; backdrop-filter: blur(5px); } .modal { width: 80%; height: 80%; display: flex; flex-direction: column; padding: 0; overflow: hidden; } .modal-header { padding: 15px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); background: rgba(255,255,255,0.02); }
</style>
EOF

# --- APP.JS ---
cat <<EOF > /opt/aetherpanel/public/app.js
const socket = io();
let currentStatus = 'OFFLINE', currentFile = '';
const cpuCtx = document.getElementById('cpuChart').getContext('2d'), ramCtx = document.getElementById('ramChart').getContext('2d');
const chartConf = (color) => ({ type: 'line', data: { labels: [], datasets: [{ data: [], borderColor: color, backgroundColor: color+'20', fill: true, pointRadius:0, tension: 0.4 }] }, options: { responsive: true, maintainAspectRatio: false, scales: { x:{display:false}, y:{beginAtZero:true, grid:{color:'#ffffff05'}} }, plugins:{legend:{display:false}}, animation:{duration:0} } });
const cpuChart = new Chart(cpuCtx, chartConf('#6366f1')), ramChart = new Chart(ramCtx, chartConf('#10b981'));
setInterval(() => { fetch('/api/stats').then(r=>r.json()).then(s => { const now = new Date().toLocaleTimeString(); if(cpuChart.data.labels.length > 20) { cpuChart.data.labels.shift(); cpuChart.data.datasets[0].data.shift(); ramChart.data.labels.shift(); ramChart.data.datasets[0].data.shift(); } cpuChart.data.labels.push(now); cpuChart.data.datasets[0].data.push(s.cpu); cpuChart.update(); ramChart.data.labels.push(now); ramChart.data.datasets[0].data.push(s.ram_used); ramChart.update(); }); }, 2000);
const term = new Terminal({ fontFamily: 'JetBrains Mono', fontSize: 13, theme: { background: '#00000000' } }); const fitAddon = new FitAddon.FitAddon(); term.loadAddon(fitAddon); term.open(document.getElementById('terminal')); window.onresize = () => fitAddon.fit(); term.onData(d => socket.emit('command', d));
socket.on('console_data', d => term.write(d)); socket.on('logs_history', d => { term.write(d); setTimeout(()=>fitAddon.fit(), 200); });
socket.on('status_change', s => { currentStatus = s; document.getElementById('status-widget').className = 'status-widget '+s; document.getElementById('status-text').innerText = s; });
socket.on('toast', d => { Toastify({ text: d.msg, duration: 3000, gravity: "bottom", position: "right", style: { background: d.type==='error'?'#ef4444':d.type==='success'?'#10b981':'#3b82f6' } }).showToast(); });
function api(ep, body=null) { const opts = body ? {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)} : {method:'POST'}; fetch('/api/'+ep, opts).then(r=>r.json()); }
function setTab(t) { document.querySelectorAll('.tab-content').forEach(e=>e.classList.remove('active')); document.querySelectorAll('.nav-btn').forEach(e=>e.classList.remove('active')); document.getElementById('tab-'+t).classList.add('active'); event.currentTarget.classList.add('active'); if(t==='console') setTimeout(()=>fitAddon.fit(), 100); if(t==='files') loadFileBrowser(); if(t==='config') loadCfg(); }
function loadFileBrowser() { fetch('/api/files').then(r=>r.json()).then(files => { const l = document.getElementById('file-list'); l.innerHTML=''; files.forEach(f => { const row = document.createElement('div'); row.className='file-row'; row.innerHTML = \`<span><i class="fa-solid \${f.isDir?'fa-folder':'fa-file'}"></i> \${f.name}</span> <span>\${f.size}</span>\`; if(!f.isDir) row.onclick = () => openEditor(f.name); l.appendChild(row); }); }); }
const editor = ace.edit("ace-editor"); editor.setTheme("ace/theme/dracula"); editor.session.setMode("ace/mode/properties");
function openEditor(f) { currentFile=f; fetch('/api/files/read', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({file:f})}).then(r=>r.json()).then(d=>{ if(!d.error){ document.getElementById('editor-modal').style.display='flex'; editor.setValue(d.content,-1); } }); }
function saveFile() { api('files/save', {file:currentFile, content:editor.getValue()}); closeEditor(); } function closeEditor() { document.getElementById('editor-modal').style.display='none'; }
function loadCfg() { fetch('/api/config').then(r=>r.json()).then(d=>{ const c=document.getElementById('cfg-list'); c.innerHTML=''; for(const[k,v] of Object.entries(d)) c.innerHTML+=\`<div class="cfg-item"><label>\${k}</label><input class="cfg-in" data-k="\${k}" value="\${v}"></div>\`; }); }
function saveCfg() { const d={}; document.querySelectorAll('.cfg-in').forEach(i=>d[i.dataset.k]=i.value); api('config', d); }
function install(t, v) { if(confirm('¿Instalar?')) { let url=''; if(t==='paper') url='https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/496/downloads/paper-1.20.4-496.jar'; if(t==='vanilla') url='https://piston-data.mojang.com/v1/objects/8dd1a28015f51b1803213892b50b7b4fc76e594d/server.jar'; api('install',{url,filename:'server.jar'}); setTab('console'); } }
setTab('stats');
EOF

# ============================================================
# 3. VERIFICACIÓN Y COMPILACIÓN
# ============================================================
echo -e "${GREEN}[3/4] 📦 Sistema base y dependencias...${NC}"

# Instalamos Node y Java SOLO si no están (para ir rápido)
export DEBIAN_FRONTEND=noninteractive
if ! command -v java &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends openjdk-21-jre-headless
fi
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
fi

echo -e "${GREEN}[4/4] 🏗️ Instalando NPM (Versión Corregida)...${NC}"
cd /opt/aetherpanel
# MOSTRAR LA VERSIÓN PARA VERIFICAR
grep "os-utils" package.json || echo "ERROR EN PACKAGE.JSON"

# INSTALAR
npm install --no-audit --no-fund --loglevel=error

# ============================================================
# 4. FINALIZAR
# ============================================================
echo -e "${GREEN}🚀 Despegando...${NC}"

cat <<EOF > /etc/systemd/system/aetherpanel.service
[Unit]
Description=AetherPanel Turbo
After=network.target

[Service]
User=root
WorkingDirectory=/opt/aetherpanel
ExecStart=/usr/bin/node server.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable aetherpanel
systemctl restart aetherpanel

ufw allow 3000/tcp > /dev/null 2>&1
ufw allow 25565/tcp > /dev/null 2>&1

IP=$(hostname -I | awk '{print $1}')
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}✅ PANEL ACTIVO: http://${IP}:3000${NC}"
echo -e "${CYAN}==========================================${NC}"