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

**Aether Panel** es una solución todo-en-uno para administrar servidores de Minecraft en entornos Linux. Diseñado para ser visualmente impactante y técnicamente robusto, elimina la necesidad de configuraciones complejas por terminal, ofreciendo una interfaz web reactiva y fácil de usar.

![Dashboard Preview](https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.png)

---

## 🐧 Sistemas Operativos Soportados

Gracias al nuevo **Instalador Universal**, Aether Panel ahora funciona en la mayoría de distribuciones Linux modernas.

| Familia | Distribuciones Probadas | Gestor de Paquetes | Estado |
| :--- | :--- | :--- | :--- |
| **Debian** | Ubuntu 20.04+, Debian 10+, Mint, Pop!_OS | `apt` | ✅ **Nativo** |
| **RHEL** | Fedora 36+, CentOS Stream 8+, AlmaLinux, Rocky | `dnf` | ✅ **Nativo** |
| **Arch** | Arch Linux, Manjaro, EndeavourOS | `pacman` | ✅ **Nativo** |
| **Otros** | OpenSUSE, Alpine, etc. | Manual | ⚠️ Compatible (Instalación manual de dependencias) |

---

## 🚀 Novedades V1.5.x

Esta versión introduce mejoras masivas en la Calidad de Vida (QoL) y la experiencia de usuario.

### 🎮 Experiencia de Usuario (UI/UX)
* **Consola Interactiva:** Ahora puedes escribir y enviar comandos directamente desde la interfaz web, con una caja de terminal dedicada.
* **Sistema de Ayuda Inteligente:** Añadidos tooltips `(?)` en todas las opciones del `server.properties` que explican qué hace cada configuración al pasar el ratón.
* **Atajos de Teclado:** Navega como un pro usando `Alt + 1` al `8` para cambiar pestañas y `ESC` para cerrar ventanas.
* **IP en Cabecera:** Haz clic en la IP del servidor en la parte superior para copiarla al portapapeles al instante.

### 🛠️ Mejoras Técnicas
* **Instalador Universal:** Script inteligente que detecta tu distribución (Ubuntu, Fedora, Arch) e instala las dependencias correctas automáticamente.
* **Actualizador de UI Independiente:** Nuevo botón para forzar la actualización de la interfaz gráfica (HTML/CSS/JS) sin reiniciar el servidor.
* **Soporte de Temas:** Todos los menús, modales y ventanas emergentes ahora son 100% compatibles con el Modo Claro y Oscuro.
* **Instalador de Versiones:** Lógica de descarga reescrita para evitar errores con Forge y Vanilla.

---

## 📦 Instalación Rápida

Accede a tu terminal como usuario `root` y ejecuta el siguiente comando mágico:

```bash
curl -sL [https://raw.githubusercontent.com/reychampi/aether-panel/main/installserver.sh](https://raw.githubusercontent.com/reychampi/aether-panel/main/installserver.sh) | bash

El instalador automático se encargará de:

    Detectar tu Sistema Operativo.

    Instalar dependencias (Java, Node.js, Git, Zip, Rsync) usando tu gestor (apt, dnf o pacman).

    Configurar el servicio automático systemd para que el panel se inicie solo.

    Descargar el núcleo del panel y los recursos gráficos.

    Iniciar el servicio en el puerto 3000.

⚡ Características

    🖥️ Monitor en Tiempo Real: Gráficas de CPU, RAM y Disco con actualización por Sockets.

    💻 Consola Web: Terminal en vivo con colores y envío de comandos.

    📂 Gestor de Archivos: Editor de texto integrado (Ace Editor) con resaltado de sintaxis.

    📥 Instalador de Núcleos: Descarga Vanilla, Paper, Fabric o Forge con un solo clic.

    📦 Sistema de Backups: Crea y restaura copias de seguridad en segundos.

    🧩 Tienda de Mods: Instalador rápido para mods populares (JEI, JourneyMap, etc.) con buscador en tiempo real.

    ⚙️ Configuración Visual: Edita server.properties con interruptores y ayudas visuales.

    🔄 Smart Updater: Sistema de actualizaciones OTA (Over-The-Air) integrado que protege tus datos.

🛠️ Solución de Problemas Frecuentes

El panel no carga en el navegador Asegúrate de que el puerto 3000 está abierto en tu firewall.

    Ubuntu/Debian: sudo ufw allow 3000/tcp

    Fedora/CentOS: sudo firewall-cmd --permanent --add-port=3000/tcp && sudo firewall-cmd --reload

Error "command not found" al instalar Si descargaste los archivos manualmente en Windows y los subiste, es posible que tengan formato incorrecto. Ejecuta en la carpeta del panel:
Bash

sed -i 's/\r$//' *.sh

<div align="center">

Desarrollado con ❤️ por ReyChampi Reportar un Bug

</div>
