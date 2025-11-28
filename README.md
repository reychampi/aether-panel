<div align="center">

<h1 align="center">
  <img src="https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.png" alt="Logo" width="30" style="vertical-align: middle; margin-right: 10px;">
  Aether Panel
</h1>

**El panel de control ligero, moderno y potente para servidores de Minecraft.**  
Gestión inteligente, monitoreo en tiempo real y diseño Glassmorphism.

[![Version](https://img.shields.io/badge/version-1.6.0-8b5cf6?style=for-the-badge&logo=git)](https://github.com/reychampi/aether-panel)
[![Status](https://img.shields.io/badge/status-stable-10b981?style=for-the-badge)](https://github.com/reychampi/aether-panel)
[![Node.js](https://img.shields.io/badge/node-%3E%3D16-339933?style=for-the-badge&logo=node.js)](https://nodejs.org/)
![Windows](https://img.shields.io/badge/Windows-Nativo-0078D6?style=for-the-badge&logo=windows)

[Instalación](#-instalación-rápida) • [Sistemas Compatibles](#-sistemas-operativos-soportados) • [Características](#-características)

</div>

---

## ✨ Descripción

**Aether Panel** es una solución todo-en-uno para administrar servidores de Minecraft.  
Diseñado para ser visualmente impactante y técnicamente robusto, elimina la necesidad de configuraciones complejas, ofreciendo una interfaz web rápida, moderna y fácil de usar tanto en **Linux** como en **Windows**.

![Dashboard Preview](https://raw.githubusercontent.com/reychampi/aether-panel/main/public/panel.png)

---

## 🐧 Sistemas Operativos Soportados

Aether Panel es ahora **Universal** y funciona nativamente en la mayoría de sistemas modernos.

| Familia | Distribuciones / SO | Método | Estado |
|--------|----------------------|--------|--------|
| **Debian** | Ubuntu 20.04+, Debian 10+, Mint | `apt` | ✅ **Nativo** |
| **RHEL** | Fedora 36+, CentOS 8+, Rocky | `dnf` | ✅ **Nativo** |
| **Arch** | Arch Linux, Manjaro | `pacman` | ✅ **Nativo** |
| **Windows** | Windows 10, 11, Server 2019+ | `.bat` | ✅ **Nativo** |

> ℹ️ **Nota para Windows:** Ya no es necesario usar WSL2. El panel se ejecuta directamente sobre Node.js en Windows.

---

## 🚀 Novedades V1.6.x

### 🎮 Experiencia de Usuario (UI/UX)

- **Consola Interactiva:** Envía comandos al servidor directamente desde la web.  
- **Sistema de Ayuda:** Tooltips `(?)` explicativos en todas las opciones del `server.properties`.  
- **Atajos de Teclado:** Navega rápido usando `Alt + 1-8` y cierra ventanas con `ESC`.  
- **IP Copiable:** Haz clic en la IP de la cabecera para copiarla al portapapeles.

### 🛠️ Mejoras Técnicas

- **Soporte Windows Nativo:** Nuevo lanzador `start_windows.bat` que instala dependencias (Node/Java) automáticamente.  
- **Instalador Linux Universal:** Detecta automáticamente tu distribución (Ubuntu/Fedora/Arch).  
- **Actualizador UI:** Botón para forzar actualización de la interfaz sin reiniciar servicios.  
- **Soporte de Temas:** Compatibilidad completa con Modo Claro y Oscuro.  
- **Resolución de Versiones:** Descarga más estable de Forge, Fabric y Paper.

---

## 📦 Instalación Rápida

### 🐧 Linux (VPS / Dedicado)

Ejecuta como **root**:

```sh
curl -sL https://raw.githubusercontent.com/reychampi/aether-panel/main/installserver.sh | bash

🪟 Windows (PC / Server)

    Descarga el repositorio (Code → Download ZIP).

    Descomprime la carpeta.

    Ejecuta start_windows.bat.

    El script instalará Node.js y Java automáticamente si no están instalados.

    El panel se abrirá automáticamente en tu navegador.

⚡ Características

    🖥️ Monitor en Tiempo Real: Gráficas dinámicas de CPU, RAM y Disco.

    💻 Consola Web: Terminal en vivo con colores y soporte de comandos.

    📂 Gestor de Archivos: Editor integrado con resaltado de sintaxis.

    📥 Instalador de Núcleos: Vanilla, Paper, Fabric y Forge a un clic.

    📦 Backups: Copias de seguridad .tar.gz con restauración instantánea.

    🧩 Tienda de Mods: Instalación directa de mods populares.

    ⚙️ Configuración Visual: Edición gráfica de server.properties.

    🔄 Smart Updater: Sistema OTA de actualizaciones sin reinstalar.

🛠️ Solución de Problemas Frecuentes
🔹 El panel no carga en el navegador

Asegúrate de abrir el puerto 3000:

Linux (UFW):

sudo ufw allow 3000/tcp

Windows:

    Cuando aparezca la ventana del Firewall, permite el acceso a Node.js.

🔹 Error command not found o $'\r' (solo Linux)

Si subiste los archivos desde Windows, puede que tengan formato CRLF.

Solución:

sed -i 's/\r$//' *.sh

<div align="center">

Desarrollado por ReyChampi
Reportar un Bug
</div> ``
