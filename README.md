# Gemelo Digital: Control de Motor por Bluetooth

Un proyecto de **"Gemelo Digital"** desarrollado para la materia de **Comunicación Electrónica**. Este proyecto integra una aplicación móvil en Flutter y un sistema embebido con Arduino Nano para controlar la velocidad de un motor DC mediante comunicación Bluetooth (HC-05), sincronizando en tiempo real un entorno físico con su representación virtual.

---

## Descripción del Proyecto

La aplicación permite controlar la intensidad y el estado de un motor de dos maneras distintas (Modo Dual), manteniendo el estado sincronizado entre el hardware y el software:

1. **Modo Físico:** Utilizando un potenciómetro real conectado al Arduino. El valor leído se transmite a la aplicación para actualizar la interfaz gráfica en tiempo real.
2. **Modo Virtual (App):** Utilizando un control deslizante (slider) en la aplicación móvil, que envía los comandos al Arduino para ajustar la velocidad del motor.

La interfaz móvil cuenta con un diseño inmersivo e indicadores visuales codificados por colores (Verde/Amarillo/Rojo) que reflejan el nivel de intensidad actual del motor.

---

## Características Principales

- **Comunicación Bidireccional:** Transmisión y recepción de datos en tiempo real entre Flutter y Arduino.
- **Control Dual:** Alternancia fluida entre el modo de control físico (potenciómetro) y el modo virtual (slider).
- **Interfaz de Usuario Dinámica:** Representación visual (Gemelo Digital) que cambia de color según la velocidad del motor.
- **Conexión Bluetooth Sencilla:** Escaneo automático y vinculación con el módulo HC-05 desde la app.

---

## Tecnologías y Hardware Utilizado

### Software
- **[Flutter](https://flutter.dev/):** Framework para el desarrollo de la aplicación móvil multiplataforma.
- **[Dart](https://dart.dev/):** Lenguaje de programación de la lógica de la app.
- **[Arduino IDE](https://www.arduino.cc/en/software):** Entorno de desarrollo para programar el microcontrolador.
- **Dependencia Flutter:** `flutter_bluetooth_serial` para la gestión de la comunicación Bluetooth clásica.

### Hardware
- **Arduino Nano** (Microcontrolador principal)
- **Módulo Bluetooth HC-05** (Comunicación serial inalámbrica)
- **Puente H (L298N)** (Controlador de potencia para el motor)
- **Motor DC**
- **Potenciómetro** (Control físico)

---

## Esquema de Conexiones (Hardware)

| Componente | Pin Arduino | Notas |
| :--- | :--- | :--- |
| **HC-05 RX** | Pin 11 (SoftwareSerial TX) | Usar divisor de tensión si es necesario |
| **HC-05 TX** | Pin 10 (SoftwareSerial RX) | |
| **Puente H (ENA)**| Pin 9 (PWM) | Control de velocidad |
| **Puente H (IN1)**| Pin 7 | Dirección del motor |
| **Puente H (IN2)**| Pin 8 | Dirección del motor |
| **Potenciómetro** | Pin A0 (Analógico) | Entrada física de velocidad |

---

## Instalación y Ejecución

### 1. Configuración del Arduino
1. Abre el archivo `Arduino/control_motor.ino` en el Arduino IDE.
2. Selecciona la placa **Arduino Nano** y el puerto correspondiente.
3. Compila y sube el código al microcontrolador.
4. Asegúrate de que el módulo HC-05 esté previamente emparejado/vinculado con tu dispositivo Android desde los ajustes de Bluetooth.

### 2. Ejecución de la App en Flutter
1. Clona este repositorio o descarga el código fuente.
2. Abre una terminal en la raíz del proyecto y ejecuta:
   ```bash
   flutter pub get
   ```
3. Conecta tu dispositivo Android (físico) mediante cable USB con la depuración USB activada.
4. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

---

## Contexto Académico

Este proyecto fue desarrollado como parte de las prácticas y evaluaciones de la asignatura **Comunicación Electrónica**. Tiene como objetivo demostrar la viabilidad y los principios de la comunicación serial inalámbrica, el procesamiento de señales analógicas y el concepto de *Digital Twin* aplicado a sistemas de lazo abierto/cerrado.


## Autor

- **Alejandro Guarin Melo** - [Visita mi Portafolio](https://guarin-dev.vercel.app/)
