#!/bin/bash

# ============================================================
# NEBULA PANEL - V1.2.3 (STABILITY PATCH)
# - Critical Fix: Replaced Axios downloader with 'wget' (Native Linux)
# - Fixed: All APIs (Vanilla/Forge/Fabric) now download correctly.
# - Visual: Version hardcoded in HTML to avoid "..." flicker.
# ============================================================
clear
set -e

# Colores
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${PURPLE}🌌 INSTALANDO NEBULA V1.2.3 (STABLE)...${NC}"

# ============================================================
# 1. PREPARACIÓN
# ============================================================
# Sincronizar hora para evitar errores de SSL
CURRENT_DATE=$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)
if [ ! -z "$CURRENT_DATE" ]; then date -s "$CURRENT_DATE" >/dev/null 2>&1; fi

systemctl stop aetherpanel >/dev/null 2>&1 || true
pkill -f node >/dev/null 2>&1 || true
rm -rf /opt/aetherpanel
mkdir -p /opt/aetherpanel/{servers/default,public,backups}

# ============================================================
# 2. BACKEND
# ============================================================

# --- PACKAGE.JSON ---
cat <<'EOF' > /opt/aetherpanel/package.json
{
  "name": "aetherpanel-nebula",
  "version": "1.2.3",
  "description": "Nebula V1.2.3 Stability",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "cors": "^2.8.5",
    "axios": "^1.6.2",
    "os-utils": "^0.0.14",
    "multer": "^1.4.5-lts.1",
    "unzipper": "^0.10.14"
  }
}
EOF

# --- SERVER.JS (BACKEND) ---
cat <<'EOF' > /opt/aetherpanel/server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');
const MCManager = require('./mc_manager');
const osUtils = require('os-utils');
const os = require('os');
const multer = require('multer');
const axios = require('axios');
const { exec } = require('child_process');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });
const upload = multer({ dest: os.tmpdir() });

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

const mcServer = new MCManager(io);
const SERVER_DIR = path.join(__dirname, 'servers', 'default');
const BACKUP_DIR = path.join(__dirname, 'backups');

// GITHUB CONFIG
const apiClient = axios.create({ headers: { 'User-Agent': 'Nebula-Panel/1.2.3' } });
const REPO_RAW = 'https://raw.githubusercontent.com/reychampi/nebula/main';
const REPO_ZIP = 'https://github.com/reychampi/nebula/archive/refs/heads/main.zip';

// --- INFO API (VERSION CHECK) ---
app.get('/api/info', (req, res) => {
    try {
        const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
        res.json({ version: pkg.version });
    } catch (e) { res.json({ version: '1.2.3' }); }
});

// --- UPDATER ---
app.get('/api/update/check', async (req, res) => {
    try {
        const localPkg = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
        const localVer = localPkg.version;
        const remotePkg = await apiClient.get(`${REPO_RAW}/package.json`);
        const remoteVer = remotePkg.data.version;

        if (remoteVer !== localVer) return res.json({ type: 'full', local: localVer, remote: remoteVer });

        // Hotfix Check
        const files = ['public/index.html', 'public/style.css', 'public/app.js'];
        let hasChanges = false;
        for (const f of files) {
            const r = (await apiClient.get(`${REPO_RAW}/${f}`)).data;
            const l = fs.readFileSync(path.join(__dirname, f), 'utf8');
            if (r.trim() !== l.trim()) { hasChanges = true; break; }
        }
        if (hasChanges) return res.json({ type: 'hotfix', local: localVer, remote: remoteVer });
        res.json({ type: 'none' });
    } catch (e) { res.json({ type: 'error', msg: e.message }); }
});

app.post('/api/update/perform', async (req, res) => {
    const { type } = req.body;
    if (type === 'full') {
        io.emit('toast', { type: 'warning', msg: '🚀 Actualizando sistema...' });
        exec(`wget ${REPO_ZIP} -O /tmp/update.zip && unzip -o /tmp/update.zip -d /tmp/nebula_update && cp -r /tmp/nebula_update/nebula-main/* /opt/aetherpanel/ && rm -rf /tmp/update.zip /tmp/nebula_update && cd /opt/aetherpanel && npm install && systemctl restart aetherpanel`);
        res.json({ success: true, mode: 'full' });
    } else if (type === 'hotfix') {
        io.emit('toast', { type: 'info', msg: '🎨 Aplicando parche visual...' });
        try {
            const files = ['public/index.html', 'public/style.css', 'public/app.js'];
            for (const f of files) {
                const c = (await apiClient.get(`${REPO_RAW}/${f}`)).data;
                fs.writeFileSync(path.join(__dirname, f), c);
            }
            res.json({ success: true, mode: 'hotfix' });
        } catch (e) { res.status(500).json({ error: e.message }); }
    }
});

// --- PROXY VERSIONES ---
app.post('/api/nebula/versions', async (req, res) => {
    const { type } = req.body;
    try {
        let list = [];
        if (type === 'vanilla') {
            const r = await apiClient.get('https://piston-meta.mojang.com/mc/game/version_manifest_v2.json');
            list = r.data.versions.filter(v => v.type === 'release').map(v => ({ id: v.id, url: v.url, type: 'vanilla' }));
        } else if (type === 'paper') {
            const r = await apiClient.get('https://api.papermc.io/v2/projects/paper');
            list = r.data.versions.reverse().map(v => ({ id: v, type: 'paper' }));
        } else if (type === 'fabric') {
            const r = await apiClient.get('https://meta.fabricmc.net/v2/versions/game');
            list = r.data.filter(v => v.stable).map(v => ({ id: v.version, type: 'fabric' }));
        } else if (type === 'forge') {
            const r = await apiClient.get('https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json');
            const p = r.data.promos;
            const s = new Set();
            Object.keys(p).forEach(k => { const v = k.split('-')[0]; if(v.match(/^\d+\.\d+(\.\d+)?$/)) s.add(v); });
            list = Array.from(s).sort((a, b) => b.localeCompare(a, undefined, { numeric: true, sensitivity: 'base' })).map(v => ({ id: v, type: 'forge' }));
        }
        res.json(list);
    } catch (e) { res.status(500).json({ error: "API Error" }); }
});

app.post('/api/nebula/resolve-vanilla', async (req, res) => {
    try { const r = await apiClient.get(req.body.url); res.json({ url: r.data.downloads.server.url }); } catch (e) { res.status(500).json({error: 'Error resolving'}); }
});

app.get('/api/stats', (req, res) => {
    osUtils.cpuUsage((cpu) => {
        let disk = 0; try { fs.readdirSync(SERVER_DIR).forEach(f => { try { disk += fs.statSync(path.join(SERVER_DIR, f)).size; } catch {} }); } catch {}
        res.json({ cpu: cpu * 100, ram_used: (os.totalmem()-os.freemem())/1048576, ram_total: os.totalmem()/1048576, disk_used: disk/1048576, disk_total: 20480 });
    });
});

app.get('/api/status', (req, res) => res.json(mcServer.getStatus()));
app.post('/api/power/:action', async (req, res) => { try{if(mcServer[req.params.action])await mcServer[req.params.action]();res.json({success:true});}catch(e){res.status(500).json({error:e.message});}});
app.get('/api/config', (req, res) => res.json(mcServer.readProperties()));
app.post('/api/config', (req, res) => { mcServer.writeProperties(req.body); res.json({success:true}); });
app.post('/api/install', async (req, res) => { try{await mcServer.installJar(req.body.url, req.body.filename);res.json({success:true});}catch(e){res.status(500).json({error:e.message});}});
app.get('/api/files', (req, res) => { const t = path.join(SERVER_DIR, (req.query.path||'').replace(/\.\./g, '')); if (!fs.existsSync(t)) return res.json([]); res.json(fs.readdirSync(t, {withFileTypes:true}).map(f => ({ name: f.name, isDir: f.isDirectory(), size: f.isDirectory()?'-':(fs.statSync(path.join(t,f.name)).size/1024).toFixed(1)+' KB'})).sort((a,b)=>a.isDir===b.isDir?0:a.isDir?-1:1)); });
app.post('/api/files/read', (req, res) => { const p = path.join(SERVER_DIR, req.body.file.replace(/\.\./g,'')); if(fs.existsSync(p)) res.json({content:fs.readFileSync(p,'utf8')}); else res.status(404).json({error:'404'}); });
app.post('/api/files/save', (req, res) => { fs.writeFileSync(path.join(SERVER_DIR, req.body.file.replace(/\.\./g,'')), req.body.content); res.json({success:true}); });
app.post('/api/files/upload', upload.single('file'), (req, res) => { if(req.file) { fs.renameSync(req.file.path, path.join(SERVER_DIR, req.file.originalname)); res.json({success:true}); } else res.json({success:false}); });
app.get('/api/backups', (req, res) => { if(!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR); res.json(fs.readdirSync(BACKUP_DIR).filter(f=>f.endsWith('.tar.gz')).map(f=>({name:f, size:(fs.statSync(path.join(BACKUP_DIR,f)).size/1048576).toFixed(2)+' MB'}))); });
app.post('/api/backups/create', (req, res) => { exec(`tar -czf "${path.join(BACKUP_DIR, 'backup-'+Date.now()+'.tar.gz')}" -C "${path.join(__dirname,'servers')}" default`, (e)=>res.json({success:!e})); });
app.post('/api/backups/delete', (req, res) => { fs.unlinkSync(path.join(BACKUP_DIR, req.body.name)); res.json({success:true}); });
app.post('/api/backups/restore', async (req, res) => { await mcServer.stop(); exec(`rm -rf "${SERVER_DIR}"/* && tar -xzf "${path.join(BACKUP_DIR, req.body.name)}" -C "${path.join(__dirname,'servers')}"`, (e)=>res.json({success:!e})); });

io.on('connection', (socket) => {
    socket.emit('logs_history', mcServer.getRecentLogs());
    socket.emit('status_change', mcServer.status);
    socket.on('command', (cmd) => mcServer.sendCommand(cmd));
});

server.listen(3000, () => console.log('Nebula V1.2.3 running'));
EOF

# --- MC_MANAGER.JS (WGET FIX) ---
cat <<'EOF' > /opt/aetherpanel/mc_manager.js
const { spawn, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

class MCManager {
    constructor(io) {
        this.io = io;
        this.process = null;
        this.serverPath = path.join(__dirname, 'servers', 'default');
        if (!fs.existsSync(this.serverPath)) fs.mkdirSync(this.serverPath, { recursive: true });
        this.status = 'OFFLINE';
        this.logs = [];
        this.ram = '4G';
        this.updatePending = false;
        this.updateCallback = null;
    }
    
    setUpdatePending(val, cb) {
        this.updatePending = val;
        this.updateCallback = cb;
        this.io.emit('toast', {type:'info', msg:'Actualización en cola. Apaga el servidor.'});
    }

    log(msg) { this.logs.push(msg); if(this.logs.length>2000)this.logs.shift(); this.io.emit('console_data', msg); }
    getStatus() { return { status: this.status, ram: this.ram }; }
    getRecentLogs() { return this.logs.join(''); }
    
    async start() {
        if (this.status !== 'OFFLINE') return;
        if (this.updatePending) {
            this.io.emit('toast', {type:'warning', msg:'Actualizando sistema...'});
            if(this.updateCallback) this.updateCallback();
            return; 
        }
        
        const eula = path.join(this.serverPath, 'eula.txt');
        if(!fs.existsSync(eula) || !fs.readFileSync(eula, 'utf8').includes('true')) fs.writeFileSync(eula, 'eula=true');
        
        let jar = fs.readdirSync(this.serverPath).find(f => f.endsWith('.jar') && !f.includes('installer'));
        if (!jar) jar = fs.readdirSync(this.serverPath).find(f => f.includes('forge') && f.endsWith('.jar'));
        if (!jar) { this.io.emit('toast', { type: 'error', msg: 'No JAR found' }); return; }

        this.status = 'STARTING';
        this.io.emit('status_change', this.status);
        this.log('\r\n>>> NEBULA: Iniciando...\r\n');
        
        this.process = spawn('java', ['-Xmx'+this.ram, '-Xms'+this.ram, '-jar', jar, 'nogui'], { cwd: this.serverPath });
        this.process.stdout.on('data', d => { const s=d.toString(); this.log(s); if(s.includes('Done')||s.includes('For help')) { this.status='ONLINE'; this.io.emit('status_change', this.status); }});
        this.process.stderr.on('data', d => this.log(d.toString()));
        this.process.on('close', () => { 
            this.status='OFFLINE'; this.process=null; this.io.emit('status_change', this.status); this.log('\r\nDetenido.\r\n');
            if(this.updatePending && this.updateCallback) { this.io.emit('console_data', '\r\n>>> ACTUALIZANDO...\r\n'); this.updateCallback(); }
        });
    }
    async stop() { if(this.process && this.status==='ONLINE') { this.status='STOPPING'; this.io.emit('status_change',this.status); this.process.stdin.write('stop\n'); return new Promise(r=>{let c=0;const i=setInterval(()=>{c++;if(this.status==='OFFLINE'||c>20){clearInterval(i);r()}},500)}); }}
    async restart() { await this.stop(); setTimeout(()=>this.start(), 3000); }
    async kill() { if(this.process) { this.process.kill('SIGKILL'); this.status='OFFLINE'; this.io.emit('status_change','OFFLINE'); }}
    sendCommand(c) { if(this.process) this.process.stdin.write(c+'\n'); }
    
    // --- FIX: USO DE WGET (INFALIBLE) ---
    async installJar(url, filename) {
        this.io.emit('toast', {type:'info', msg:'Descargando núcleo...'});
        this.log(`\r\nDescargando: ${url}\r\n`);
        
        // Limpiar
        fs.readdirSync(this.serverPath).forEach(f => { if(f.endsWith('.jar')) fs.unlinkSync(path.join(this.serverPath, f)); });
        
        const target = path.join(this.serverPath, filename);
        const cmd = `wget -q -O "${target}" "${url}"`; // -q = quiet, -O = output file
        
        return new Promise((resolve, reject) => {
            exec(cmd, (error, stdout, stderr) => {
                if (error) {
                    this.io.emit('toast', {type:'error', msg:'Error al descargar'});
                    this.log(`Error WGET: ${error.message}\n`);
                    reject(error);
                } else {
                    this.io.emit('toast', {type:'success', msg:'Instalado correctamente'});
                    this.log('Descarga completada.\n');
                    resolve();
                }
            });
        });
    }

    readProperties() { try{return fs.readFileSync(path.join(this.serverPath,'server.properties'),'utf8').split('\n').reduce((a,l)=>{const[k,v]=l.split('=');if(k&&!l.startsWith('#'))a[k.trim()]=v?v.trim():'';return a;},{});}catch{return{};} }
    writeProperties(p) { fs.writeFileSync(path.join(this.serverPath,'server.properties'), '#Gen by Nebula\n'+Object.entries(p).map(([k,v])=>`${k}=${v}`).join('\n')); }
}
module.exports = MCManager;
EOF

# ============================================================
# 3. FRONTEND
# ============================================================

# --- INDEX.HTML ---
cat <<'EOF' > /opt/aetherpanel/public/index.html
<!DOCTYPE html>
<html lang="es" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NEBULA</title>
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
            <h3 id="up-title">Actualización</h3>
            <p id="update-text" style="color:var(--muted); margin-bottom:20px">...</p>
            <div id="up-actions" style="display:flex; flex-direction:column; gap:10px"></div>
        </div>
    </div>

    <div class="app-layout">
        <aside class="sidebar">
            <div class="brand"><div class="brand-logo"><i class="fa-solid fa-meteor"></i></div><div class="brand-text"><span id="sidebar-version-text">V1.2.3</span> <span>NEBULA</span></div></div>
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
                <div class="server-info"><h1>Nebula Dashboard</h1><div class="badges"><span class="badge badge-primary" id="header-version">V1.2.3</span><span class="badge">Stable</span></div></div>
                <div class="actions">
                    <button onclick="api('power/start')" class="btn-control start"><i class="fa-solid fa-play"></i></button>
                    <button onclick="api('power/restart')" class="btn-control restart"><i class="fa-solid fa-rotate-right"></i></button>
                    <button onclick="api('power/stop')" class="btn-control stop"><i class="fa-solid fa-power-off"></i></button>
                    <button onclick="api('power/kill')" class="btn-control kill"><i class="fa-solid fa-skull-crossbones"></i></button>
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
                    <div class="card-header"><h3>Configuración</h3><button onclick="saveCfg()" class="btn btn-primary">Guardar</button></div>
                    <div id="cfg-list" class="cfg-grid"></div>
                    <div style="padding:20px;margin-top:20px;border-top:1px solid var(--border)">
                        <button onclick="checkUpdate()" class="btn" style="background:#8b5cf6;width:100%;justify-content:center;border:1px solid var(--border)"><i class="fa-solid fa-rotate"></i> BUSCAR ACTUALIZACIONES</button>
                    </div>
                </div>
            </div>
        </main>
    </div>
    <script src="app.js"></script>
</body>
</html>
EOF

# --- STYLE.CSS ---
cat <<'EOF' > /opt/aetherpanel/public/style.css
:root { --bg: #0f0f13; --sb: #050507; --card-bg: #121214; --glass: rgba(255,255,255,0.03); --border: rgba(255,255,255,0.06); --p: #8b5cf6; --txt: #e4e4e7; --muted: #71717a; --radius: 12px; --console-bg: #000000; }
[data-theme="light"] { --bg: #f8fafc; --sb: #ffffff; --card-bg: #ffffff; --glass: rgba(0,0,0,0.02); --border: rgba(0,0,0,0.08); --p: #6366f1; --txt: #0f172a; --muted: #64748b; --console-bg: #1e293b; }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Manrope', sans-serif; background: var(--bg); color: var(--txt); height: 100vh; overflow: hidden; transition: background 0.3s, color 0.3s; }
.glass { background: var(--glass); backdrop-filter: blur(12px); border: 1px solid var(--border); border-radius: var(--radius); background-color: var(--card-bg); }
.app-layout { display: flex; height: 100%; }
.sidebar { width: 260px; background: var(--sb); border-right: 1px solid var(--border); padding: 24px; display: flex; flex-direction: column; transition: background 0.3s; height: 100vh; justify-content: space-between; }
.brand { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; font-weight: 800; font-size: 1.4rem; flex-shrink: 0; } .brand span { color: var(--p); } .brand-logo { color: var(--p); font-size: 1.2rem; }
nav { flex: 1; overflow-y: auto; margin-bottom: 20px; } .sidebar-footer { margin-top: auto; flex-shrink: 0; }
.nav-label { font-size: 0.7rem; color: var(--muted); font-weight: 700; margin: 20px 0 8px 12px; letter-spacing: 1px; }
.nav-btn { width: 100%; background: transparent; border: none; padding: 12px; color: var(--muted); text-align: left; border-radius: 8px; cursor: pointer; font-family: inherit; font-weight: 500; display: flex; align-items: center; gap: 12px; transition: 0.2s; }
.nav-btn:hover { background: var(--glass); color: var(--txt); } .nav-btn.active { background: rgba(139,92,246,0.1); color: var(--p); font-weight: 700; }
.theme-switcher { display: flex; background: var(--glass); padding: 4px; border-radius: 8px; margin-bottom: 15px; border: 1px solid var(--border); }
.theme-btn { flex: 1; background: transparent; border: none; color: var(--muted); padding: 6px; border-radius: 6px; cursor: pointer; transition: 0.2s; } .theme-btn:hover { color: var(--txt); } .theme-btn.active { background: var(--bg); color: var(--p); box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
.status-widget { background: var(--glass); padding: 12px; border-radius: 8px; border: 1px solid var(--border); display: flex; align-items: center; gap: 12px; }
.status-indicator { width: 8px; height: 8px; border-radius: 50%; background: #ef4444; } .ONLINE .status-indicator { background: #10b981; box-shadow: 0 0 10px rgba(16,185,129,0.4); }
main { flex: 1; padding: 32px 40px; display: flex; flex-direction: column; overflow-y: auto; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
.actions { display: flex; gap: 10px; align-items: center; flex-direction: row !important; }
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
EOF

# --- APP.JS ---
cat <<'EOF' > /opt/aetherpanel/public/app.js
const socket = io();
let currentPath = '', currentFile = '', allVersions = [];

// GET VERSION INFO
fetch('/api/info').then(r=>r.json()).then(d => {
    document.getElementById('sidebar-version-text').innerText = 'V' + d.version;
    document.getElementById('header-version').innerText = 'V' + d.version;
});

function setTheme(mode) { localStorage.setItem('theme', mode); updateThemeUI(mode); }
function updateThemeUI(mode) {
    let apply = mode; if(mode==='auto') apply = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark':'light';
    document.documentElement.setAttribute('data-theme', apply);
    document.querySelectorAll('.theme-btn').forEach(b => b.classList.remove('active'));
    const btn = document.querySelector(`.theme-btn[onclick="setTheme('${mode}')"]`);
    if(btn) btn.classList.add('active');
}
updateThemeUI(localStorage.getItem('theme') || 'dark');

function checkUpdate() {
    Toastify({text:'Buscando...', style:{background:'var(--p)'}}).showToast();
    fetch('/api/update/check').then(r=>r.json()).then(d => {
        const m = document.getElementById('update-modal');
        const t = document.getElementById('update-text');
        const a = document.getElementById('up-actions');
        const ti = document.getElementById('up-title');
        
        if(d.type === 'full') {
            ti.innerText = "Actualización Mayor";
            t.innerText = `Versión local: ${d.local}\nNueva versión: ${d.remote}\n\nSe requiere reinicio completo del servidor.`;
            a.innerHTML = `<button onclick="doUpdate('full')" class="btn btn-primary">ACTUALIZAR SISTEMA (${d.remote})</button><button onclick="document.getElementById('update-modal').style.display='none'" class="btn btn-ghost">Cancelar</button>`;
            m.style.display='flex';
        } else if (d.type === 'hotfix') {
            ti.innerText = "Parche Visual Disponible";
            t.innerText = `Versión ${d.local} (Hotfix)\nSe han detectado mejoras visuales.\nSe actualizará sin reiniciar el servidor.`;
            a.innerHTML = `<button onclick="doUpdate('hotfix')" class="btn" style="background:#10b981;color:white">APLICAR CAMBIOS VISUALES</button><button onclick="document.getElementById('update-modal').style.display='none'" class="btn btn-ghost">Cancelar</button>`;
            m.style.display='flex';
        } else if (d.type === 'none') {
            Toastify({text:'Sistema actualizado', style:{background:'#10b981'}}).showToast();
        }
    });
}

function doUpdate(type) {
    document.getElementById('update-modal').style.display='none';
    fetch('/api/update/perform', {
        method: 'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({type})
    }).then(r=>r.json()).then(d=>{
        if(d.mode === 'hotfix') {
            Toastify({text:'Interfaz actualizada. Recargando...', style:{background:'#10b981'}}).showToast();
            setTimeout(()=>location.reload(), 1500);
        }
    });
}

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
# 4. FINALIZAR
# ============================================================
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends curl wget git tar zip unzip ufw openjdk-21-jre-headless
cd /opt/aetherpanel
npm install --no-audit --no-fund --loglevel=error
systemctl daemon-reload
systemctl enable aetherpanel
systemctl restart aetherpanel
ufw allow 3000/tcp >/dev/null 2>&1
IP=$(hostname -I | awk '{print $1}')
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}🌌 NEBULA V1.2.3 ONLINE: http://${IP}:3000${NC}"
echo -e "${CYAN}==========================================${NC}"