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
        this.configPath = path.join(__dirname, 'nebula.json');
        this.loadConfig();
    }

    loadConfig() {
        try {
            if (fs.existsSync(this.configPath)) {
                const conf = JSON.parse(fs.readFileSync(this.configPath, 'utf8'));
                this.ram = conf.ram || '4G';
                this.config = {
                    serverName: conf.serverName || 'Nebula Dashboard',
                    themeColor: conf.themeColor || '#8b5cf6',
                    particles: conf.particles !== undefined ? conf.particles : true,
                    ram: this.ram
                };
            } else {
                this.ram = '4G';
                this.config = { serverName: 'Nebula Dashboard', themeColor: '#8b5cf6', particles: true, ram: '4G' };
            }
        } catch (e) {
            this.ram = '4G';
            this.config = { serverName: 'Nebula Dashboard', themeColor: '#8b5cf6', particles: true, ram: '4G' };
        }
    }

    saveConfig() {
        try {
            const data = { ...this.config, ram: this.ram };
            fs.writeFileSync(this.configPath, JSON.stringify(data, null, 2));
        } catch (e) { console.error('Error saving config', e); }
    }

    updateConfig(newConf) {
        this.config = { ...this.config, ...newConf };
        if (newConf.ram) this.ram = newConf.ram;
        this.saveConfig();
        this.io.emit('config_update', this.config);
    }

    setRam(ram) {
        this.ram = ram;
        this.config.ram = ram;
        this.saveConfig();
    }

    log(msg) { this.logs.push(msg); if (this.logs.length > 2000) this.logs.shift(); this.io.emit('console_data', msg); }
    getStatus() { return { status: this.status, ram: this.ram }; }
    getRecentLogs() { return this.logs.join(''); }

    async start() {
        if (this.status !== 'OFFLINE') return;
        const eula = path.join(this.serverPath, 'eula.txt');
        if (!fs.existsSync(eula) || !fs.readFileSync(eula, 'utf8').includes('true')) fs.writeFileSync(eula, 'eula=true');
        let jar = fs.readdirSync(this.serverPath).find(f => f.endsWith('.jar') && !f.includes('installer'));
        if (!jar) jar = fs.readdirSync(this.serverPath).find(f => f.includes('forge') && f.endsWith('.jar'));
        if (!jar) { this.io.emit('toast', { type: 'error', msg: 'No JAR found' }); return; }

        this.status = 'STARTING';
        this.io.emit('status_change', this.status);
        this.log('\r\n>>> NEBULA: Iniciando con ' + this.ram + ' de RAM...\r\n');

        // Ensure RAM format is correct for Java (e.g., 4G, 4096M)
        const ramArg = this.ram.toUpperCase().endsWith('G') || this.ram.toUpperCase().endsWith('M') ? this.ram : this.ram + 'G';

        this.process = spawn('java', ['-Xmx' + ramArg, '-Xms' + ramArg, '-jar', jar, 'nogui'], { cwd: this.serverPath });
        this.process.stdout.on('data', d => { const s = d.toString(); this.log(s); if (s.includes('Done') || s.includes('For help')) { this.status = 'ONLINE'; this.io.emit('status_change', this.status); } });
        this.process.stderr.on('data', d => this.log(d.toString()));
        this.process.on('close', () => {
            this.status = 'OFFLINE'; this.process = null; this.io.emit('status_change', this.status); this.log('\r\nDetenido.\r\n');
        });
    }
    async stop() { if (this.process && this.status === 'ONLINE') { this.status = 'STOPPING'; this.io.emit('status_change', this.status); this.process.stdin.write('stop\n'); return new Promise(r => { let c = 0; const i = setInterval(() => { c++; if (this.status === 'OFFLINE' || c > 20) { clearInterval(i); r() } }, 500) }); } }
    async restart() { await this.stop(); setTimeout(() => this.start(), 3000); }
    async kill() { if (this.process) { this.process.kill('SIGKILL'); this.status = 'OFFLINE'; this.io.emit('status_change', 'OFFLINE'); } }
    sendCommand(c) { if (this.process) this.process.stdin.write(c + '\n'); }
    async installJar(url, filename) {
        this.io.emit('toast', { type: 'info', msg: 'Descargando núcleo...' }); this.log(`\r\nDescargando: ${url}\r\n`);
        fs.readdirSync(this.serverPath).forEach(f => { if (f.endsWith('.jar')) fs.unlinkSync(path.join(this.serverPath, f)); });
        const target = path.join(this.serverPath, filename);
        const cmd = `wget -q -O "${target}" "${url}"`;
        return new Promise((resolve, reject) => { exec(cmd, (error) => { if (error) { this.io.emit('toast', { type: 'error', msg: 'Error al descargar' }); reject(error); } else { this.io.emit('toast', { type: 'success', msg: 'Instalado correctamente' }); resolve(); } }); });
    }
    readProperties() { try { return fs.readFileSync(path.join(this.serverPath, 'server.properties'), 'utf8').split('\n').reduce((a, l) => { const [k, v] = l.split('='); if (k && !l.startsWith('#')) a[k.trim()] = v ? v.trim() : ''; return a; }, {}); } catch { return {}; } }
    writeProperties(p) { fs.writeFileSync(path.join(this.serverPath, 'server.properties'), '#Gen by Nebula\n' + Object.entries(p).map(([k, v]) => `${k}=${v}`).join('\n')); }
}
module.exports = MCManager;
