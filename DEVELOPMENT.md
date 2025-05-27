# 🔥 Smash Seeding Chile - Guía de Desarrollo

## 🚀 Inicio Rápido

Para iniciar todos los servicios de desarrollo de una vez:

```bash
bin/dev
```

Este comando iniciará automáticamente:
- **Rails server** (puerto 3000)
- **Tailwind CSS watcher** (recarga automática de estilos)
- **Solid Queue** (procesamiento de jobs en segundo plano)
- **Mailcatcher** (servidor de emails para desarrollo)

## 📋 Servicios Incluidos

### 🌐 Servidor Web
- **URL**: http://localhost:3000
- **Comando manual**: `bin/rails server`

### 🎨 CSS Watcher (Tailwind)
- **Función**: Recarga automática de estilos CSS
- **Comando manual**: `bin/rails tailwindcss:watch`

### 💼 Jobs en Segundo Plano
- **Función**: Procesa jobs de sincronización (torneos, eventos, seeds)
- **Panel de administración**: http://localhost:3000/jobs
- **Comando manual**: `bin/rails solid_queue:start`

### 📧 Mailcatcher
- **Interfaz web**: http://localhost:1080
- **Puerto SMTP**: 1025
- **Función**: Captura y muestra emails enviados durante desarrollo
- **Comando manual**: `mailcatcher --foreground --http-ip=0.0.0.0 --smtp-ip=0.0.0.0`

## 🔧 Comandos Individuales

Si prefieres ejecutar servicios por separado:

```bash
# Solo el servidor Rails
bin/rails server

# Solo el watcher de CSS
bin/rails tailwindcss:watch

# Solo el procesador de jobs
bin/rails solid_queue:start

# Solo Mailcatcher
mailcatcher --foreground
```

## 👥 Cuentas de Prueba

El sistema incluye dos cuentas por defecto:

```
Email: rudolfaraya@gmail.com
Contraseña: 

Email: alonivanrivalvera@gmail.com
Contraseña: 
```

Para crear las cuentas (si no existen):
```bash
bin/rails db:seed
```

## 🛠️ Configuración Adicional

### Base de Datos
```bash
# Crear y migrar la base de datos
bin/rails db:create db:migrate

# Cargar datos de prueba
bin/rails db:seed
```

### Dependencias
```bash
# Instalar gems
bundle install

# Instalar foreman (si no está instalado)
gem install foreman
```

## 🔍 Debugging

El script `bin/dev` está configurado para permitir debugging remoto:
- `RUBY_DEBUG_OPEN=true`
- `RUBY_DEBUG_LAZY=true`

## 📝 Notas

- **Puerto por defecto**: 3000 (configurable con `PORT=4000 bin/dev`)
- **Detener servicios**: Ctrl+C
- **Logs**: Todos los servicios muestran sus logs en la misma terminal
- **Colores**: Cada servicio tiene un color diferente en los logs para fácil identificación

## 🚨 Solución de Problemas

### Mailcatcher no inicia
```bash
gem install mailcatcher
```

### Puerto 3000 ocupado
```bash
PORT=4000 bin/dev
```

### Jobs no se procesan
Verifica que Solid Queue esté corriendo y revisa los logs en http://localhost:3000/jobs 