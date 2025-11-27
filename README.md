<div align="center">

<img src="https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.png" alt="Aether Panel Logo" width="120" height="120">

# 🌌 Aether Panel

**El panel de control ligero, moderno y potente para servidores de Minecraft.**  
Gestión inteligente, monitoreo en tiempo real y diseño Glassmorphism.

[![Version](https://img.shields.io/badge/version-1.5.2-8b5cf6?style=for-the-badge&logo=git)](https://github.com/reychampi/aether-panel)
[![Status](https://img.shields.io/badge/status-stable-10b981?style=for-the-badge)](https://github.com/reychampi/aether-panel)
[![Node.js](https://img.shields.io/badge/node-%3E%3D16-339933?style=for-the-badge&logo=node.js)](https://nodejs.org/)

[Instalación](#-instalación-rápida) • [Sistemas Compatibles](#-sistemas-operativos-soportados) • [Características](#-características)

</div>

---

## ✨ Descripción

**Aether Panel** es una solución completa para administrar servidores de Minecraft en Linux.  
Está diseñado para ser visualmente impactante, técnicamente sólido y extremadamente fácil de usar, eliminando configuraciones manuales innecesarias por terminal.

![Dashboard Preview](https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.png)

---

## 🐧 Sistemas Operativos Soportados

Aether Panel funciona en prácticamente cualquier distro Linux moderna gracias a su instalador universal.

| Familia | Distribuciones Probadas | Gestor | Estado |
|--------|---------------------------|--------|--------|
| **Debian** | Ubuntu 20.04+, Debian 10+, Mint | `apt` | ✅ Nativo |
| **RHEL** | Fedora 36+, CentOS 8+, Rocky | `dnf` | ✅ Nativo |
| **Arch** | Arch Linux, Manjaro | `pacman` | ✅ Nativo |

---

## 🚀 Novedades V1.5.x

### 🎮 Experiencia de Usuario (UI/UX)

- **Consola Interactiva:** Terminal web con capacidad de enviar comandos al instante.  
- **Sistema de Ayuda:** Tooltips `(?)` con explicaciones en todas las opciones de `server.properties`.  
- **Atajos de Teclado:** Usa `Alt + 1-8` para navegar rápidamente.  
- **IP Copiable:** Clic para copiar la IP del servidor.

### 🛠️ Mejoras Técnicas

- **Instalador Universal:** Detecta automáticamente tu distro (Ubuntu/Fedora/Arch).  
- **Actualizador UI:** Botón para refrescar la interfaz sin reiniciar servicios.  
- **Temas:** Soporte total para Light/Dark Mode.  
- **Resolución de Versiones:** Descargas de Forge/Fabric/Paper más estables.

---

## 📦 Instalación Rápida

Ejecuta este comando como `root`:

<pre>
curl -sL https://raw.githubusercontent.com/reychampi/aether-panel/main/installserver.sh | bash
</pre>

El instalador se encargará de:

- Detectar tu SO  
- Instalar dependencias (Java, Node.js, Git, Zip, Rsync)  
- Configurar el servicio systemd  
- Descargar archivos del panel  
- Iniciar el servicio en el puerto **3000**

---

## ⚡ Características

- 🖥️ **Monitor en Tiempo Real:** CPU, RAM y disco con actualización por sockets.  
- 💻 **Consola Web:** Terminal en vivo con colores y soporte de comandos.  
- 📂 **Gestor de Archivos:** Editor integrado con resaltado de sintaxis.  
- 📥 **Instalador de Núcleos:** Descarga Vanilla, Paper, Fabric y Forge.  
- 📦 **Sistema de Backups:** Genera y restaura copias en segundos.  
- 🧩 **Tienda de Mods:** Instalación directa de mods populares.  
- ⚙️ **Configuración Visual:** Edita opciones de `server.properties` con UI gráfica.  
- 🔄 **Smart Updater:** Sistema OTA para actualizar el panel.  

---

## 🛠️ Solución de Problemas Frecuentes

### 🔹 El panel no carga en el navegador

Verifica que el puerto **3000** esté abierto:

**Ubuntu/Debian**
<pre>
sudo ufw allow 3000/tcp
</pre>

**Fedora/CentOS**
<pre>
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
</pre>

---

### 🔹 Error: `command not found` o `$'\r'`

Esto ocurre si los `.sh` fueron subidos desde Windows (fin de línea CRLF).  
Ejecuta en la carpeta del panel:

<pre>
sed -i 's/\r$//' *.sh
</pre>

---

<div align="center">

**Desarrollado por ReyChampi**  
⭐ Si te gusta el proyecto, ¡dale una estrella en GitHub!

</div>
