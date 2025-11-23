#!/bin/bash

# ============================================================
# AETHER NEBULA v3.0 - HYPERNOVA ULTIMATE
# Scheduler + Pre-Wipe Backup + Advanced Config + Visual Match
# ============================================================

set -e
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
VIOLET='\033[0;35m'
NC='\033[0m'

clear
echo -e "${MAGENTA}=================================================${NC}"
echo -e "${VIOLET}   ✨ NEBULA v3.0 (HYPERNOVA ULTIMATE)           ${NC}"
echo -e "${MAGENTA}=================================================${NC}"

# 1. ACTUALIZAR DEPENDENCIAS
apt-get update -y > /dev/null
apt-get install -y nodejs npm curl unzip zip tar build-essential ufw openjdk-21-jre-headless openjdk-17-jre-headless openjdk-8-jre-headless > /dev/null || true

# 2. PREPARAR DIRECTORIOS
mkdir -p /opt/aetherpanel/public
mkdir -p /opt/aetherpanel/servers/default
mkdir -p /opt/aetherpanel/backups

# 3. BACKEND (SCHEDULER + BACKUP LOGIC)
cat <<EOF > /opt/aetherpanel/package.json
{
  "name": "aether-nebula-v3",
  "version": "3.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1",
    "archiver": "^6.0.1",
    "systeminformation": "^5.21.0",
    "axios": "^1.6.2",
    "node-schedule": "^2.1.1"
  }
}
EOF

cat <<EOF > /opt/aetherpanel/server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const multer = require('multer');
const MCManager = require('./mc_manager');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

const mcServer = new MCManager(io);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, '/opt/aetherpanel/servers/default'),
  filename: (req, file, cb) => cb(null, file.originalname)
});
const upload = multer({ storage: storage });

const auth = (req, res, next) => {
    const cfg = mcServer.getLabsConfig();
    if(cfg.password && cfg.password !== '') {
        if(req.headers['x-auth'] !== cfg.password) return res.status(403).json({error: 'Acceso denegado'});
    }
    next();
};

// API
app.get('/api/status', (req, res) => res.json(mcServer.getStatus()));
app.get('/api/stats', async (req, res) => res.json(await mcServer.getPerformance()));
app.get('/api/config', (req, res) => res.json(mcServer.getConfig()));
app.post('/api/config', auth, (req, res) => { mcServer.saveConfig(req.body); res.json({success:true}); });
app.post('/api/game-settings', auth, (req, res) => { mcServer.updateServerProperties(req.body); res.json({success:true}); });
app.post('/api/power/:action', auth, async (req, res) => {
    try { if(mcServer[req.params.action]) { await mcServer[req.params.action](); res.json({success:true}); } } 
    catch(e) { res.status(500).json({error:e.message}); }
});
app.post('/api/install', auth, async (req, res) => {
    try { await mcServer.installJar(req.body); res.json({success:true}); }
    catch(e) { res.status(500).json({error:e.message}); }
});
app.post('/api/upload', auth, upload.single('file'), (req, res) => res.json({success: true}));
app.get('/api/files/list', (req, res) => res.json(mcServer.listFiles()));
app.post('/api/files/read', auth, (req, res) => res.send(mcServer.readFile(req.body.file)));
app.post('/api/files/save', auth, (req, res) => { mcServer.saveFile(req.body.file, req.body.content); res.json({success:true}); });
app.get('/api/players', (req, res) => res.json(mcServer.players));
app.post('/api/players/action', auth, (req, res) => { mcServer.playerAction(req.body.action, req.body.player); res.json({success:true}); });
app.get('/api/labs/info', (req, res) => res.json(mcServer.getLabsConfig()));
app.post('/api/labs/set-auth', (req, res) => { mcServer.setLabsAuth(req.body.password); res.json({success:true}); });
app.post('/api/labs/set-discord', auth, (req, res) => { mcServer.setDiscord(req.body.url); res.json({success:true}); });
app.post('/api/labs/set-schedule', auth, (req, res) => { mcServer.setSchedule(req.body.hours); res.json({success:true}); });
app.post('/api/labs/wipe', auth, async (req, res) => { await mcServer.labsWipe(); res.json({success:true}); });
app.post('/api/labs/backup', auth, async (req, res) => { await mcServer.createBackup(); res.json({success:true}); });
app.get('/api/versions/:type', async (req, res) => {
    try { res.json(await mcServer.fetchVersions(req.params.type)); } 
    catch(e) { res.status(500).json({error:e.message}); }
});

io.on('connection', (s) => {
    s.emit('logs', mcServer.getRecentLogs());
    s.on('command', (c) => mcServer.sendCommand(c));
});

server.listen(3000, () => console.log('Nebula v3.0 Hypernova Online'));
EOF

cat <<EOF > /opt/aetherpanel/mc_manager.js
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const archiver = require('archiver');
const si = require('systeminformation');
const schedule = require('node-schedule');

class MCManager {
    constructor(io) {
        this.io = io;
        this.basePath = path.join(__dirname, 'servers', 'default');
        this.settingsPath = path.join(__dirname, 'servers', 'aether.json');
        this.backupPath = path.join(__dirname, 'backups');
        if (!fs.existsSync(this.basePath)) fs.mkdirSync(this.basePath, { recursive: true });
        if (!fs.existsSync(this.backupPath)) fs.mkdirSync(this.backupPath, { recursive: true });
        
        this.settings = this.loadSettings();
        this.status = 'OFFLINE';
        this.logs = [];
        this.players = [];
        this.job = null;

        setInterval(() => this.checkCrash(), 5000);
        setInterval(() => this.updatePlayerList(), 10000);
        this.initSchedule();
    }

    loadSettings() {
        if (fs.existsSync(this.settingsPath)) return JSON.parse(fs.readFileSync(this.settingsPath, 'utf8'));
        return { ram: '4G', javaVersion: '21', labs: { password: '', discord: '', restartInterval: 0 } }; 
    }
    saveConfig(data) { if(data.settings) { this.settings = { ...this.settings, ...data.settings }; this.persist(); } }
    persist() { fs.writeFileSync(this.settingsPath, JSON.stringify(this.settings, null, 2)); }
    
    getLabsConfig() { return this.settings.labs || {}; }
    setLabsAuth(pwd) { this.settings.labs.password = pwd; this.persist(); }
    setDiscord(url) { this.settings.labs.discord = url; this.persist(); this.sendDiscord('🔔 Webhook Conectado'); }
    
    // --- SCHEDULER ---
    setSchedule(hours) {
        this.settings.labs.restartInterval = parseInt(hours);
        this.persist();
        this.initSchedule();
    }
    initSchedule() {
        if(this.job) this.job.cancel();
        const h = this.settings.labs.restartInterval;
        if(h > 0) {
            this.log('⏰ Auto-Restart programado cada ' + h + ' horas.');
            // Schedule simple interval
            this.job = schedule.scheduleJob(\`0 */\${h} * * *\`, async () => {
                this.log('⏰ Ejecutando reinicio programado...');
                this.sendDiscord('⏰ Reinicio Automático Programado');
                await this.restart();
            });
        }
    }

    async sendDiscord(msg, color=0x7289DA) {
        const url = this.settings.labs?.discord;
        if(!url) return;
        try { await axios.post(url, { embeds: [{ title: 'Hypernova Server', description: msg, color: color, timestamp: new Date() }] }); } catch(e) {}
    }

    checkCrash() {
        if(this.status === 'ONLINE' && !this.process) {
            this.log('⚠ Crash detectado. Reiniciando...');
            this.sendDiscord('⚠ Crash Detectado. Reiniciando.', 0xFF0000);
            this.start();
        }
    }

    // --- FILE OPS ---
    listFiles() {
        try {
            const list = fs.readdirSync(this.basePath);
            return list.map(file => {
                const stat = fs.statSync(path.join(this.basePath, file));
                return {name: file, type: stat.isDirectory()?'dir':'file', size: (stat.size/1024).toFixed(1)+'KB'};
            }).sort((a,b) => (a.type==='dir' ? -1 : 1));
        } catch { return []; }
    }
    readFile(file) { if(file.includes('..')) return 'Denied'; return fs.readFileSync(path.join(this.basePath, file), 'utf8'); }
    saveFile(file, content) { if(file.includes('..')) return; fs.writeFileSync(path.join(this.basePath, file), content); }

    updatePlayerList() { if(this.status === 'ONLINE' && this.process) this.process.stdin.write('list\n'); }
    playerAction(action, player) { 
        if(this.process) {
            this.log(\`👮 \${action.toUpperCase()} \${player}\`);
            this.process.stdin.write(\`\${action} \${player}\n\`); 
        }
    }

    async getPerformance() {
        const mem = await si.mem(); const cpu = await si.currentLoad();
        return { ram_used: (mem.active/1073741824).toFixed(2), ram_total: (mem.total/1073741824).toFixed(2), cpu: cpu.currentLoad.toFixed(1) };
    }

    // --- CORE ---
    async start() {
        if (this.status !== 'OFFLINE') return;
        this.fixEula();
        let jar = this.findJar();
        if(!jar) { this.log('❌ ERROR: No jar found.'); return; }
        this.status = 'STARTING'; this.io.emit('status_change', this.status);
        this.sendDiscord('🟢 Servidor Iniciando...', 0x00FF00);
        let cmd = this.getJavaCmd();
        const ram = this.settings.ram || '4G';
        const args = ['-Xms'+ram, '-Xmx'+ram, '-DPaper.IgnoreJavaVersion=true'];
        if (parseInt(this.settings.javaVersion) >= 17) args.push('--add-modules=jdk.incubator.vector');
        args.push('-jar', jar, 'nogui');
        this.process = spawn(cmd, args, { cwd: this.basePath });
        this.process.stdout.on('data', d => {
            const s = d.toString(); this.log(s);
            if(s.includes('players online:')) {
                const parts = s.split(':');
                if(parts.length > 1) { const names = parts[parts.length-1].trim().split(', '); this.players = names[0]!==''?names:[]; }
            }
            if(s.includes('Done')) { this.status='ONLINE'; this.io.emit('status_change',this.status); this.sendDiscord('✅ Online'); }
        });
        this.process.stderr.on('data', d => this.log('LOG: '+d));
        this.process.on('close', c => { this.status='OFFLINE'; this.process=null; this.io.emit('status_change',this.status); this.sendDiscord('🔴 Offline'); this.players=[]; });
    }
    async stop() { if(this.process) { this.status='STOPPING'; this.io.emit('status_change',this.status); this.process.stdin.write('stop\n'); } }
    async restart() { await this.stop(); setTimeout(() => this.start(), 5000); }
    sendCommand(c) { if(this.process) this.process.stdin.write(c+'\n'); }
    
    getJavaCmd() {
        const v = this.settings.javaVersion;
        if(v==='8') return '/usr/lib/jvm/java-8-openjdk-amd64/bin/java';
        if(v==='17') return '/usr/lib/jvm/java-17-openjdk-amd64/bin/java';
        return '/usr/lib/jvm/java-21-openjdk-amd64/bin/java';
    }
    findJar() {
        const files = fs.readdirSync(this.basePath);
        if(files.includes('fabric-server-launch.jar')) return 'fabric-server-launch.jar';
        if(files.includes('server.jar')) return 'server.jar';
        return files.find(f => (f.includes('forge')||f.includes('neoforge')) && f.endsWith('.jar') && !f.includes('installer'));
    }
    fixEula() { fs.writeFileSync(path.join(this.basePath, 'eula.txt'), 'eula=true'); }
    getConfig() { return { properties: this.readPropertiesRaw(), settings: this.settings }; }
    readPropertiesRaw() {
        try {
            if(!fs.existsSync(path.join(this.basePath, 'server.properties'))) return {};
            const c = fs.readFileSync(path.join(this.basePath, 'server.properties'), 'utf8');
            const p = {};
            c.split('\n').forEach(l => { if(l.includes('=') && !l.startsWith('#')) { const [k,v]=l.split('='); p[k.trim()]=v?v.trim():''; }});
            return p;
        } catch { return {}; }
    }
    updateServerProperties(newProps) {
        let current = this.readPropertiesRaw();
        for (const [key, val] of Object.entries(newProps)) current[key] = val;
        let c = '#Hypernova Config v3\n'; for (const [k, v] of Object.entries(current)) c += \`\${k}=\${v}\n\`;
        fs.writeFileSync(path.join(this.basePath, 'server.properties'), c);
    }
    
    async installJar(data) {
        const { url, type } = data;
        if (!url) throw new Error('URL error');
        this.log('🌐 Downloading ' + type);
        let dest = 'server.jar';
        if(type.includes('forge')) dest = 'installer.jar';
        if(type==='fabric') dest = 'server.jar';
        return new Promise((res, rej) => {
            const curl = spawn('curl', ['-L','-k','-f','-o', dest, url], { cwd: this.basePath });
            curl.stderr.on('data', d => {
                const m = d.toString().match(/(\d+)(\.\d+)?%/);
                if(m) this.io.emit('install_progress', Math.floor(parseFloat(m[0])));
            });
            curl.on('close', async c => {
                if(c===0) { this.io.emit('install_progress', 100); if(type.includes('forge')) await this.runInstaller(); res(); } else rej(new Error('Curl error'));
            });
        });
    }
    async runInstaller() {
        this.log('⚙️ Installing Forge...');
        this.io.emit('install_progress', 'installing');
        return new Promise((res, rej) => {
            const p = spawn('java', ['-jar', 'installer.jar', '--installServer'], { cwd: this.basePath });
            p.stdout.on('data', d => this.log('Install: '+d));
            p.on('close', c => {
                if(c===0) { try{fs.unlinkSync(path.join(this.basePath, 'installer.jar'))}catch(e){} res(); } else rej(new Error('Install failed'));
            });
        });
    }
    async fetchVersions(type) {
        if(type==='paper') return (await axios.get('https://api.papermc.io/v2/projects/paper')).data.versions.reverse();
        if(type==='vanilla') return (await axios.get('https://piston-meta.mojang.com/mc/game/version_manifest_v2.json')).data.versions.filter(v=>v.type==='release').map(v=>v.id);
        if(type==='forge') return Object.keys((await axios.get('https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json')).data.promos).map(k=>k.split('-')[0]).filter((v,i,a)=>a.indexOf(v)===i).sort().reverse();
        if(type==='fabric') return (await axios.get('https://meta.fabricmc.net/v2/versions/game')).data.filter(v=>v.stable).map(v=>v.version);
        return [];
    }
    
    // --- BACKUP & WIPE (WITH PRE-BACKUP) ---
    async createBackup(prefix='backup') {
        this.log('📦 Creando Backup...');
        const name = \`\${prefix}-\${Date.now()}.zip\`;
        const out = fs.createWriteStream(path.join(this.backupPath, name));
        const arc = archiver('zip', { zlib: { level: 9 } });
        return new Promise((res, rej) => {
            out.on('close', () => { this.log('✅ Backup guardado: '+name); res(); });
            arc.pipe(out);
            arc.glob('**/*', { cwd: this.basePath, ignore: ['*.jar', 'logs/*'] }); // Backup inteligente (sin jars pesados)
            arc.finalize();
        });
    }
    
    async labsWipe() {
        if(this.status !== 'OFFLINE') throw new Error('Stop first');
        this.log('⚠ Iniciando Protocolo Wipe...');
        await this.createBackup('pre-wipe'); // AUTO BACKUP
        const files = fs.readdirSync(this.basePath);
        for(const f of files) { if(f!=='aether.json') fs.rmSync(path.join(this.basePath, f), {recursive:true, force:true}); }
        this.log('✅ Servidor reseteado (Backup creado).');
    }
    
    log(msg) { this.logs.push(msg); if(this.logs.length>600)this.logs.shift(); this.io.emit('console_line', msg); }
}
module.exports = MCManager;
EOF

# 4. FRONTEND v3.0 (VISUAL MATCH + EXPANDED SETTINGS)
cat <<EOF > /opt/aetherpanel/public/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hypernova v3.0</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/remixicon@3.5.0/fonts/remixicon.css">
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;500;700;800&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
    <script src="/socket.io/socket.io.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.32.6/ace.js"></script>
</head>
<body>
    <div class="bg-noise"></div>
    <div class="app">
        <aside class="sidebar">
            <div class="brand">
                <div class="logo-wrap"><i class="ri-sparkling-2-fill"></i></div>
                <div class="brand-txt">HYPERNOVA <span class="ver">v3.0</span></div>
            </div>
            
            <nav>
                <div class="cat">SERVER</div>
                <button onclick="nav('console')" class="nav-btn active"><i class="ri-terminal-box-fill"></i> Consola</button>
                <button onclick="nav('stats')" class="nav-btn"><i class="ri-pulse-fill"></i> Monitor</button>
                
                <div class="cat">GESTIÓN</div>
                <button onclick="nav('files')" class="nav-btn"><i class="ri-folder-5-fill"></i> Archivos</button>
                <button onclick="nav('players')" class="nav-btn"><i class="ri-group-fill"></i> Jugadores</button>
                <button onclick="nav('install')" class="nav-btn"><i class="ri-cloud-windy-fill"></i> Versiones</button>
                
                <div class="cat">CONFIG</div>
                <button onclick="nav('game')" class="nav-btn"><i class="ri-settings-4-fill"></i> Juego</button>
                <button onclick="nav('labs')" class="nav-btn labs-btn"><i class="ri-flask-fill"></i> Labs</button>
            </nav>
            <div class="sb-footer">
                <div class="theme-toggles">
                    <button onclick="setTheme('light')" class="t-btn" title="Claro"><i class="ri-sun-fill"></i></button>
                    <button onclick="setTheme('dark')" class="t-btn" title="Oscuro"><i class="ri-moon-fill"></i></button>
                    <button onclick="setTheme('auto')" class="t-btn" title="Auto"><i class="ri-computer-line"></i></button>
                </div>
                <div id="status-badge" class="badge offline"><i class="ri-shut-down-line"></i> OFFLINE</div>
            </div>
        </aside>

        <main>
            <header>
                <h2 id="page-title">Consola</h2>
                <div class="ctrls">
                    <button class="btn go" onclick="pwr('start')"><i class="ri-play-fill"></i> Iniciar</button>
                    <button class="btn wa" onclick="pwr('restart')"><i class="ri-refresh-line"></i> Reiniciar</button>
                    <button class="btn st" onclick="pwr('stop')"><i class="ri-stop-fill"></i> Detener</button>
                </div>
            </header>

            <div id="v-console" class="view active">
                <div id="dl-ovl" class="overlay"><div class="modal"><i class="ri-download-cloud-2-line spin"></i><h3>Procesando...</h3><div class="track"><div id="prog-bar"></div></div><span id="prog-txt">0%</span></div></div>
                <div class="term-wrap"><div id="logs"></div><div class="inp-wrap"><i class="ri-arrow-right-s-line"></i><input id="cmd" placeholder="Ejecutar comando... (Flecha Arriba para historial)" autocomplete="off"></div></div>
            </div>

            <div id="v-game" class="view">
                <div class="grid-2">
                    <div class="card">
                        <h3>General</h3>
                        <div class="inp-g"><label>Nombre Servidor (MOTD)</label><input id="g-motd"></div>
                        <div class="inp-g"><label>Máximo Jugadores</label><input type="number" id="g-max"></div>
                        <div class="inp-g"><label>Puerto (Server Port)</label><input type="number" id="g-port" placeholder="25565"></div>
                    </div>
                    <div class="card">
                        <h3>Mundo</h3>
                        <div class="inp-g"><label>Nombre Nivel (Level Name)</label><input id="g-level"></div>
                        <div class="inp-g"><label>Semilla (Seed)</label><input id="g-seed" placeholder="Aleatorio..."></div>
                        <div class="inp-g"><label>Dificultad</label><select id="g-diff"><option value="peaceful">Pacífico</option><option value="easy">Fácil</option><option value="normal">Normal</option><option value="hard">Difícil</option></select></div>
                    </div>
                    <div class="card">
                        <h3>Jugabilidad</h3>
                        <div class="sw-row"><span>Modo Crackeado</span><label class="switch"><input type="checkbox" id="g-crack"><span class="slider"></span></label></div>
                        <div class="sw-row"><span>PVP</span><label class="switch"><input type="checkbox" id="g-pvp"><span class="slider"></span></label></div>
                        <div class="sw-row"><span>Hardcore</span><label class="switch"><input type="checkbox" id="g-hc"><span class="slider"></span></label></div>
                        <div class="sw-row"><span>Vuelo (Fly)</span><label class="switch"><input type="checkbox" id="g-fly"><span class="slider"></span></label></div>
                        <div class="sw-row"><span>Bloques de Comandos</span><label class="switch"><input type="checkbox" id="g-cmd"><span class="slider"></span></label></div>
                    </div>
                    <div class="card">
                        <h3>Avanzado</h3>
                        <div class="sw-row"><span>Spawn Monstruos</span><label class="switch"><input type="checkbox" id="g-monsters"><span class="slider"></span></label></div>
                        <div class="sw-row"><span>Spawn NPCs</span><label class="switch"><input type="checkbox" id="g-npcs"><span class="slider"></span></label></div>
                        <div class="sw-row"><span>Allow Nether</span><label class="switch"><input type="checkbox" id="g-nether"><span class="slider"></span></label></div>
                        <div class="sw-row"><span>White List</span><label class="switch"><input type="checkbox" id="g-white"><span class="slider"></span></label></div>
                        <div class="inp-g" style="margin-top:10px"><label>View Distance</label><input type="number" id="g-view"></div>
                    </div>
                </div>
                <button class="btn pr full" onclick="saveG()">Guardar Toda la Configuración</button>
            </div>

            <div id="v-labs" class="view">
                <div class="grid-2">
                    <div class="card">
                        <h3>Automatización</h3>
                        <div class="inp-g"><label>Reiniciar cada (Horas)</label><input type="number" id="sch-hr" placeholder="0 para desactivar"></div>
                        <button class="btn sc full" onclick="saveSch()">Programar</button>
                        <div class="sep"></div>
                        <h3>Notificaciones</h3>
                        <div class="inp-g"><label>Discord Webhook</label><input id="dc-url"></div>
                        <button class="btn sc full" onclick="saveDc()">Guardar Webhook</button>
                    </div>
                    <div class="card danger">
                        <h3>Zona Peligrosa</h3>
                        <div class="acts-col">
                            <button class="btn wa full" onclick="backup()">Crear Backup Manual</button>
                            <button class="btn st full" onclick="wipe()">WIPE SERVER (Auto-Backup)</button>
                            <button class="btn st full" onclick="pwr('kill')">FORCE KILL</button>
                        </div>
                    </div>
                </div>
            </div>

            <div id="v-stats" class="view"><div class="grid-2"><div class="card chart-card"><h3>RAM</h3><div class="chart-box"><canvas id="ramChart"></canvas></div></div><div class="card chart-card"><h3>CPU</h3><div class="chart-box"><canvas id="cpuChart"></canvas></div></div></div></div>
            <div id="v-files" class="view"><div id="file-browser"><div class="card"><div class="card-head"><h3>Explorador</h3><div class="acts"><button class="btn sm sc" onclick="document.getElementById('f-inp').click()"><i class="ri-upload-cloud-2-line"></i> Subir</button><input type="file" id="f-inp" hidden></div></div><div id="file-list" class="file-grid"></div></div></div><div id="file-editor" style="display:none"><div class="card full-h"><div class="card-head"><h3>Editando: <span id="ed-name"></span></h3><div class="acts"><button class="btn sm pr" onclick="saveFile()"><i class="ri-save-3-line"></i></button><button class="btn sm sc" onclick="closeEd()"><i class="ri-close-line"></i></button></div></div><div id="ace-editor"></div></div></div></div>
            <div id="v-players" class="view"><div class="card"><h3>Jugadores Online</h3><div id="pl-list" class="pl-grid"><em>Sin jugadores</em></div></div></div>
            <div id="v-install" class="view"><div class="card"><h3>Instalador Universal</h3><div class="row-grid"><div class="grp"><label>Software</label><select id="ldr" onchange="getV()"><option value="paper">PaperMC</option><option value="purpur">Purpur</option><option value="vanilla">Vanilla</option><option value="forge">Forge</option><option value="fabric">Fabric</option></select></div><div class="grp"><label>Versión</label><select id="ver" disabled><option>...</option></select></div></div><button class="btn pr full" onclick="inst()">Instalar Software</button></div></div>
        </main>
    </div>
    <script src="app.js"></script>
</body>
</html>
EOF

# 5. CSS EXACTO (VISUAL MATCHING)
cat <<EOF > /opt/aetherpanel/public/style.css
:root {
    --bg:#09090b; --sb:#121215; --cd:#18181b; --bd:#27272a; --tx:#e4e4e7; --dm:#888;
    --acc:#7c3aed; --ac-gl:rgba(99,102,241,0.2); --grn:#10b981; --red:#ef4444; --ylw:#f59e0b;
    --font:'Outfit', sans-serif;
}
body.light { --bg:#f8fafc; --sb:#ffffff; --cd:#ffffff; --bd:#e2e8f0; --tx:#0f172a; --dm:#64748b; --acc:#4f46e5; }

* { box-sizing:border-box; transition:background 0.2s, color 0.2s, border 0.2s; }
body { margin:0; background:var(--bg); color:var(--tx); font-family:var(--font); height:100vh; overflow:hidden; }
.bg-noise { position:fixed; top:0; left:0; width:100%; height:100%; opacity:0.03; z-index:-1; background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.6'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E"); }

.app { display:flex; height:100%; }
.sidebar { width:260px; background:var(--sb); border-right:1px solid var(--bd); display:flex; flex-direction:column; padding:25px; z-index:10; }
.brand { display:flex; align-items:center; gap:12px; margin-bottom:35px; }
/* Custom Icon matching image */
.logo-wrap { width:36px; height:36px; background:linear-gradient(135deg, #7c3aed, #c084fc); border-radius:8px; display:flex; align-items:center; justify-content:center; color:white; font-size:1.2rem; box-shadow:0 0 15px rgba(124,58,237,0.4); }
.brand-txt { font-weight:800; font-size:1.1rem; letter-spacing:0.5px; }
.ver { font-size:0.65rem; background:rgba(124,58,237,0.1); color:var(--acc); padding:2px 6px; border-radius:4px; margin-left:6px; border:1px solid rgba(124,58,237,0.2); }

.nav-btn { width:100%; text-align:left; padding:10px 14px; background:transparent; border:none; color:var(--dm); border-radius:8px; cursor:pointer; font-weight:600; display:flex; gap:12px; transition:0.2s; margin-bottom:4px; }
.nav-btn:hover { background:var(--bd); color:var(--tx); }
.nav-btn.active { background:linear-gradient(90deg, rgba(124,58,237,0.1), transparent); color:var(--acc); border-left:3px solid var(--acc); border-radius:0 8px 8px 0; }
.nav-btn i { font-size:1.1rem; }
.cat { font-size:0.7rem; font-weight:700; color:var(--dm); margin:20px 0 8px 10px; letter-spacing:1px; }

main { flex:1; padding:40px; display:flex; flex-direction:column; overflow:hidden; }
header { display:flex; justify-content:space-between; align-items:center; margin-bottom:25px; }
.btn { padding:10px 20px; border-radius:8px; border:none; font-weight:700; cursor:pointer; color:#fff; transition:0.2s; display:inline-flex; align-items:center; gap:8px; }
.go{background:var(--grn)} .wa{background:var(--ylw);color:#000} .st{background:var(--red)} .pr{background:var(--acc)} .sc{background:var(--bd);color:var(--tx)} 
.full { width:100%; justify-content:center; margin-top:15px; }

.card { background:var(--cd); border:1px solid var(--bd); border-radius:16px; padding:24px; margin-bottom:20px; box-shadow:0 4px 20px rgba(0,0,0,0.02); }
.grid-2 { display:grid; grid-template-columns:repeat(auto-fit, minmax(300px, 1fr)); gap:20px; overflow-y:auto; padding-bottom:20px; }

/* Inputs matched to image */
label { display:block; font-size:0.85rem; color:var(--dm); margin-bottom:8px; font-weight:600; }
input, select { width:100%; padding:12px; background:var(--bg); border:1px solid var(--bd); border-radius:8px; color:var(--tx); outline:none; margin-bottom:15px; transition:0.2s; }
input:focus { border-color:var(--acc); box-shadow:0 0 0 3px var(--ac-gl); }

/* Toggle Switch matching image */
.sw-row { display:flex; justify-content:space-between; align-items:center; padding:12px 0; border-bottom:1px solid var(--bd); }
.sw-row:last-child { border-bottom:none; }
.switch { position:relative; display:inline-block; width:44px; height:24px; }
.switch input { opacity:0; width:0; height:0; }
.slider { position:absolute; cursor:pointer; top:0; left:0; right:0; bottom:0; background-color:#3f3f46; transition:.4s; border-radius:34px; }
.slider:before { position:absolute; content:""; height:18px; width:18px; left:3px; bottom:3px; background-color:white; transition:.4s; border-radius:50%; }
input:checked + .slider { background-color:var(--acc); }
input:checked + .slider:before { transform:translateX(20px); }

/* Views */
.view { display:none; flex-direction:column; height:100%; } .view.active { display:flex; animation:fi 0.3s ease; }
@keyframes fi { from{opacity:0;transform:translateY(10px)} to{opacity:1;transform:translateY(0)} }

.term-wrap { flex:1; background:#0a0a0c; border-radius:12px; border:1px solid var(--bd); display:flex; flex-direction:column; overflow:hidden; }
#logs { flex:1; padding:15px; overflow-y:auto; font-family:'JetBrains Mono'; font-size:0.85rem; color:#ccc; white-space:pre-wrap; }
.inp-wrap { border-top:1px solid #333; padding:12px; background:#111; display:flex; gap:10px; }
#cmd { background:transparent; border:none; color:var(--grn); flex:1; outline:none; font-family:'JetBrains Mono'; }

.sb-footer { margin-top:auto; padding-top:20px; border-top:1px solid var(--bd); }
.theme-toggles { display:flex; background:var(--bd); padding:4px; border-radius:8px; margin-bottom:15px; }
.t-btn { flex:1; background:transparent; border:none; color:var(--dm); padding:6px; border-radius:6px; cursor:pointer; }
.t-btn.active { background:var(--bg); color:var(--acc); }
.badge { text-align:center; padding:8px; font-weight:800; font-size:0.75rem; border-radius:6px; }
.off { background:rgba(239,68,68,0.15); color:var(--red); } .on { background:rgba(16,185,129,0.15); color:var(--grn); }

/* Overlay & Upload */
.overlay { position:absolute; inset:0; background:rgba(0,0,0,0.8); display:none; justify-content:center; align-items:center; z-index:99; }
.modal { background:var(--cd); padding:30px; border-radius:16px; width:300px; text-align:center; border:1px solid var(--bd); }
.track { height:6px; background:var(--bg); border-radius:3px; margin:15px 0; overflow:hidden; }
#prog-bar { height:100%; width:0; background:var(--acc); transition:width 0.2s; }
.spin { animation:spin 1s linear infinite; font-size:2rem; color:var(--acc); margin-bottom:10px; display:block; } @keyframes spin { 100% { transform:rotate(360deg); } }
.upl-zone { border:2px dashed var(--bd); padding:40px; text-align:center; border-radius:12px; cursor:pointer; }
.upl-zone:hover { border-color:var(--acc); background:rgba(124,58,237,0.05); }
.danger { border-left:4px solid var(--red); } .sep { height:1px; background:var(--bd); margin:20px 0; }
EOF

# 6. JS LOGIC (HISTORY + EXPANDED SETTINGS)
cat <<EOF > /opt/aetherpanel/public/app.js
const socket=io(); const l=document.getElementById('logs');
let pwd='', ramC, cpuC, cmdHist=[], histIdx=-1;

// THEME
function initT(){const s=localStorage.getItem('theme');if(s==='light')document.body.classList.add('light');}
function setTheme(m){
    localStorage.setItem('theme',m); document.body.classList.remove('light');
    if(m==='light'||(m==='auto'&&window.matchMedia('(prefers-color-scheme:light)').matches)) document.body.classList.add('light');
    updateChartsColor(m);
}
initT();

// COMMAND HISTORY
const cmdInput = document.getElementById('cmd');
cmdInput.addEventListener('keydown', e => {
    if(e.key==='ArrowUp'){ 
        if(histIdx < cmdHist.length-1) { histIdx++; cmdInput.value=cmdHist[cmdHist.length-1-histIdx]; }
        e.preventDefault();
    }
    if(e.key==='ArrowDown'){
        if(histIdx > 0) { histIdx--; cmdInput.value=cmdHist[cmdHist.length-1-histIdx]; }
        else { histIdx=-1; cmdInput.value=''; }
        e.preventDefault();
    }
    if(e.key==='Enter'){
        const v=cmdInput.value; if(v){socket.emit('command',v); cmdHist.push(v); histIdx=-1; cmdInput.value='';}
    }
});

function getH(){return pwd?{'Content-Type':'application/json','x-auth':pwd}:{'Content-Type':'application/json'};}

socket.on('console_line',t=>{const d=document.createElement('div');d.innerText=t;l.appendChild(d);l.scrollTop=l.scrollHeight;});
socket.on('status_change',s=>{const b=document.getElementById('status-badge');b.innerText=s;b.className='badge '+(s==='ONLINE'?'on':'off');});
socket.on('install_progress',p=>{
    const o=document.getElementById('dl-ovl'); const f=document.getElementById('prog-bar'); const t=document.getElementById('prog-txt');
    if(p==='installing'){t.innerText='Instalando...';f.style.width='100%';}
    else{o.style.display='flex';f.style.width=p+'%';t.innerText=p+'%';}
    if(p>=100 && p!=='installing') setTimeout(()=>{o.style.display='none'},2000);
});

function nav(v){
    document.querySelectorAll('.view').forEach(e=>e.classList.remove('active'));
    document.querySelectorAll('.nav-btn').forEach(e=>e.classList.remove('active'));
    document.getElementById('v-'+v).classList.add('active'); event.currentTarget.classList.add('active');
    document.getElementById('page-title').innerText = event.currentTarget.innerText.trim();
    if(v==='game') loadG(); if(v==='labs') loadL(); if(v==='files') loadFiles(); if(v==='players') loadPl();
}
function pwr(a){fetch('/api/power/'+a,{method:'POST',headers:getH()});}

// SETTINGS (EXPANDED MAP)
function loadG(){fetch('/api/config').then(r=>r.json()).then(d=>{
    const p=d.properties;
    document.getElementById('g-motd').value=p.motd||'';
    document.getElementById('g-max').value=p['max-players']||20;
    document.getElementById('g-port').value=p['server-port']||25565;
    document.getElementById('g-level').value=p['level-name']||'world';
    document.getElementById('g-seed').value=p['level-seed']||'';
    document.getElementById('g-view').value=p['view-distance']||10;
    document.getElementById('g-diff').value=p['difficulty']||'normal';
    document.getElementById('g-mode').value=p['gamemode']||'survival';
    
    const setSw=(id,k)=>document.getElementById(id).checked=(p[k]!=='false');
    const setSwInv=(id,k)=>document.getElementById(id).checked=(p[k]==='false');
    
    setSwInv('g-crack','online-mode');
    setSw('g-pvp','pvp');
    setSw('g-hc','hardcore');
    setSw('g-fly','allow-flight');
    setSw('g-cmd','enable-command-block');
    setSw('g-monsters','spawn-monsters');
    setSw('g-npcs','spawn-npcs');
    setSw('g-nether','allow-nether');
    setSw('g-white','white-list');
});}

function saveG(){
    const p={
        'motd':document.getElementById('g-motd').value,
        'max-players':document.getElementById('g-max').value,
        'server-port':document.getElementById('g-port').value,
        'level-name':document.getElementById('g-level').value,
        'level-seed':document.getElementById('g-seed').value,
        'view-distance':document.getElementById('g-view').value,
        'difficulty':document.getElementById('g-diff').value,
        'gamemode':document.getElementById('g-mode').value,
        'online-mode':document.getElementById('g-crack').checked?'false':'true',
        'pvp':document.getElementById('g-pvp').checked?'true':'false',
        'hardcore':document.getElementById('g-hc').checked?'true':'false',
        'allow-flight':document.getElementById('g-fly').checked?'true':'false',
        'enable-command-block':document.getElementById('g-cmd').checked?'true':'false',
        'spawn-monsters':document.getElementById('g-monsters').checked?'true':'false',
        'spawn-npcs':document.getElementById('g-npcs').checked?'true':'false',
        'allow-nether':document.getElementById('g-nether').checked?'true':'false',
        'white-list':document.getElementById('g-white').checked?'true':'false'
    };
    fetch('/api/game-settings',{method:'POST',headers:getH(),body:JSON.stringify(p)}).then(()=>alert('Guardado'));
}

// LABS
function loadL(){fetch('/api/labs/info').then(r=>r.json()).then(d=>{pwd=d.password||'';document.getElementById('l-pass').value=pwd;document.getElementById('dc-url').value=d.discord||'';document.getElementById('sch-hr').value=d.restartInterval||'';});}
function saveDc(){fetch('/api/labs/set-discord',{method:'POST',headers:getH(),body:JSON.stringify({url:document.getElementById('dc-url').value})}).then(()=>alert('OK'));}
function saveAuth(){pwd=document.getElementById('l-pass').value;fetch('/api/labs/set-auth',{method:'POST',headers:getH(),body:JSON.stringify({password:pwd})}).then(()=>alert('OK'));}
function saveSch(){fetch('/api/labs/set-schedule',{method:'POST',headers:getH(),body:JSON.stringify({hours:document.getElementById('sch-hr').value})}).then(()=>alert('Scheduler OK'));}
function wipe(){if(confirm('Se hará un Backup antes de borrar. ¿Seguir?'))fetch('/api/labs/wipe',{method:'POST',headers:getH()}).then(()=>alert('Wipe OK'));}
function backup(){fetch('/api/labs/backup',{method:'POST',headers:getH()}).then(()=>alert('Backup OK'));}

// CHART & FILES (Simplified for length)
function initCharts(){const r=document.getElementById('ramChart').getContext('2d');const c=document.getElementById('cpuChart').getContext('2d');const cfg={type:'line',data:{labels:Array(20).fill(''),datasets:[{data:Array(20).fill(0),borderColor:'#7c3aed',fill:true,backgroundColor:'rgba(124,58,237,0.1)'}]},options:{responsive:true,maintainAspectRatio:false,scales:{y:{min:0,max:100}}}};ramC=new Chart(r,JSON.parse(JSON.stringify(cfg)));cpuC=new Chart(c,JSON.parse(JSON.stringify(cfg)));}
function updateStats(){fetch('/api/stats').then(r=>r.json()).then(d=>{ramC.data.datasets[0].data.push((d.ram_used/d.ram_total)*100);ramC.data.datasets[0].data.shift();ramC.update();cpuC.data.datasets[0].data.push(d.cpu);cpuC.data.datasets[0].data.shift();cpuC.update();});}
setInterval(()=>{if(document.getElementById('v-stats').classList.contains('active'))updateStats()},2000);
let editor; function initEditor(){editor=ace.edit("ace-editor");editor.setTheme("ace/theme/twilight");editor.session.setMode("ace/mode/properties");}
function loadFiles(){fetch('/api/files/list').then(r=>r.json()).then(d=>{const c=document.getElementById('file-list');c.innerHTML='';d.forEach(f=>{c.innerHTML+=\`<div class="f-row" onclick="edit('\${f.name}',\${f.type==='dir'})"><span>\${f.name}</span><small>\${f.size}</small></div>\`})});}
function edit(n,d){if(d)return;curFile=n;fetch('/api/files/read',{method:'POST',headers:getH(),body:JSON.stringify({file:n})}).then(r=>r.text()).then(c=>{document.getElementById('file-browser').style.display='none';document.getElementById('file-editor').style.display='block';document.getElementById('ed-name').innerText=n;editor.setValue(c,-1);});}
function saveFile(){fetch('/api/files/save',{method:'POST',headers:getH(),body:JSON.stringify({file:curFile,content:editor.getValue()})}).then(()=>alert('Guardado'));}
function closeEd(){document.getElementById('file-browser').style.display='block';document.getElementById('file-editor').style.display='none';}
document.getElementById('f-inp').onchange=e=>{const f=e.target.files[0];const fd=new FormData();fd.append('file',f);fetch('/api/upload',{method:'POST',headers:{'x-auth':pwd},body:fd}).then(()=>alert('Subido'));loadFiles();};
function loadPl(){fetch('/api/players').then(r=>r.json()).then(p=>{const c=document.getElementById('pl-list');c.innerHTML=p.length?'': '<em>Vacío</em>';p.forEach(n=>{c.innerHTML+=\`<div class="pl-card"><b>\${n}</b><div><button class="btn st sm" onclick="plAct('kick','\${n}')">Kick</button></div></div>\`})});}
function plAct(a,p){fetch('/api/players/action',{method:'POST',headers:getH(),body:JSON.stringify({action:a,player:p})}).then(()=>loadPl());}
async function getV(){const t=document.getElementById('ldr').value;const s=document.getElementById('ver');s.innerHTML='<option>...</option>';s.disabled=true;try{const r=await fetch('/api/versions/'+t);const l=await r.json();s.innerHTML='';l.forEach(v=>s.innerHTML+=\`<option value="\${v}">\${v}</option>\`);s.disabled=false;}catch{}}
async function inst(){const t=document.getElementById('ldr').value;const v=document.getElementById('ver').value;if(confirm('Instalar?'))fetch('/api/install',{method:'POST',headers:getH(),body:JSON.stringify({url:'',type:t,ver:v})});}

initCharts(); initEditor();
EOF

# 5. FINALIZAR
cd /opt/aetherpanel
npm install
systemctl restart aetherpanel

IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}>>> NEBULA v3.0 HYPERNOVA ONLINE.${NC}"
echo -e "URL: http://${IP}:3000"