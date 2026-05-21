# AlarMap 📍⏰

AlarMap es una aplicación móvil desarrollada en Flutter que te permite configurar alarmas basadas en ubicación (Geofencing). ¡Ideal para no pasarte de tu parada en el transporte público o para recordatorios al llegar a un destino!

## Características Principales 🚀

* **Monitoreo robusto en Segundo Plano:** Funciona de manera confiable incluso con la pantalla apagada gracias a la integración de Foreground Services, WakeLocks y bypass del Doze Mode en Android.
* **Asistente de Configuración de Permisos:** Interfaz guiada para asegurar que el usuario otorgue permisos críticos (Ubicación "Todo el tiempo", Optimización de Batería y Mostrar sobre otras apps).
* **Notificaciones de Alta Prioridad (Full Screen Intent):** Asegura que la alarma despierte el dispositivo y aparezca en pantalla completa al llegar al destino.
* **Soporte TTS (Text-to-Speech):** Alertas por voz ("Atención, has llegado a tu destino...") repetitivas.
* **Búsqueda Inteligente:** Búsqueda rápida de lugares usando Google Places y gestión de ubicaciones favoritas.
* **Sonidos Personalizados:** Selección de ringtones del sistema operativo o audios personalizados (Feature PRO).
* **Simulación de Rutas:** Herramientas para probar el funcionamiento de la alarma de manera simulada antes del viaje real.

## Requisitos y Permisos 🔒

Debido a las restricciones modernas de Android (11+ / 14+), la app requiere configuraciones específicas que se solicitan en el *RequiredConfigScreen*:

1. **Ubicación (Permitir todo el tiempo):** Esencial para monitorear la distancia cuando la app está minimizada.
2. **Sin restricciones de batería:** Evita que el sistema operativo suspenda o mate el proceso durante viajes largos (Ignore Battery Optimizations).
3. **Permiso de Superposición (System Alert Window):** Permite mostrar el botón para apagar la alarma sobre otras aplicaciones.
4. **Permiso de Pantalla Completa (Android 14+):** Necesario para que la actividad de alarma se lance automáticamente con la pantalla bloqueada.

## Configuración y Ejecución 🛠️

### Prerrequisitos
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión estable más reciente).
* Dispositivo físico Android o emulador con Google Play Services (Recomendado probar en dispositivo físico por los sensores GPS).

### Instalación

1. Clona este repositorio:
   ```bash
   git clone https://github.com/CARsoftAR/alarMaps.git
   ```
2. Descarga las dependencias de Flutter:
   ```bash
   cd alarMaps
   flutter pub get
   ```
3. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

## Arquitectura 🏗️
El proyecto utiliza **Riverpod** para el manejo reactivo del estado y está estructurado por capas o *features* (alarm, map, settings, terms, core) para mantener un código escalable y ordenado.

## Descargo de Responsabilidad ⚠️
AlarMap es una herramienta de asistencia basada en geolocalización. Factores externos fuera del control del desarrollador (precisión y señal del GPS, interferencias de red, gestión agresiva de energía por capas de personalización como MIUI/EMUI) pueden afectar el momento exacto en el que suena la alarma. Su uso en situaciones críticas es bajo riesgo del usuario.
