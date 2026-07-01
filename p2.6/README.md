# P2.6 | Monitor Actividad Física — Wearable BLE → Teléfono

Dos apps Flutter independientes:

- `wearable_app/` — corre en el wearable (Wear OS). Simula sensores y los
  expone como un **servidor GATT BLE** (rol periférico).
- `telefono_app/` — corre en el teléfono. Escanea, se conecta como
  **cliente BLE** (rol central) y muestra los datos.

UUIDs compartidos (idénticos en ambos proyectos, `lib/ble_constants.dart`):

| Característica     | UUID                                   | Formato              |
|---------------------|-----------------------------------------|----------------------|
| Servicio            | `12345678-1234-1234-1234-123456789abc` | —                    |
| Pasos               | `aaaaaaaa-0001-1234-1234-123456789abc` | int32 little-endian  |
| Ritmo cardiaco      | `aaaaaaaa-0002-1234-1234-123456789abc` | uint8 (bpm)          |
| Calorías            | `aaaaaaaa-0003-1234-1234-123456789abc` | int16 little-endian  |
| Estado de actividad | `aaaaaaaa-0004-1234-1234-123456789abc` | string utf8          |

## Ajuste técnico respecto a la especificación original

`flutter_blue_plus` (usado como cliente en `telefono_app`) **no implementa
rol periférico/servidor GATT en Android**, solo rol central. Por eso
`wearable_app` usa [`bluetooth_low_energy`](https://pub.dev/packages/bluetooth_low_energy)
(`PeripheralManager`) para anunciar el servicio y notificar las
características de verdad — ver `wearable_app/lib/ble_server.dart`.

## Limitación real: wearable emulado + teléfono físico

El Bluetooth del emulador de Wear OS es **virtual** (Rootcanal): nunca toca
el radio Bluetooth real de la máquina host. Rootcanal permite que dos
*emuladores* se vean entre sí, pero **no existe puente hacia el Bluetooth
real de un teléfono físico**. En esta combinación concreta (wearable
emulado + teléfono físico), el advertising BLE del wearable JAMÁS será
visible para el teléfono, sin importar el plugin usado.

En un wearable físico real, este problema no existiría: el `BleServer`
tal como está implementado (con `bluetooth_low_energy`) funcionaría
directamente, sin necesidad de ningún respaldo.

### Respaldo: WebSocket sobre el mismo cable/adb

Para poder hacer la demo funcional de todos modos, `wearable_app` levanta
siempre, en paralelo al intento de advertising BLE, un **servidor
WebSocket** (`wearable_app/lib/fallback_server.dart`, puerto `8080`, solo
`dart:io`, sin dependencias extra) que transmite el mismo estado.

`telefono_app` intenta primero BLE real (`services/ble_client.dart`, 15s de
timeout) y si no conecta, cae automáticamente al WebSocket
(`services/ws_fallback_client.dart`). La UI (`ActivityProvider`) no sabe ni
le importa qué transporte se usó — ambos alimentan el mismo `ActivityData`.

El puente entre el emulador y el teléfono físico se arma reutilizando los
puertos USB/adb que ya están conectados a la misma máquina de desarrollo
(no depende de que ambos estén en la misma red WiFi):

```bash
# IDs de los dispositivos conectados
flutter devices
adb devices

# Emulador de Wear OS -> máquina host (puerto 8080 del emulador llega a localhost:8080 del host)
adb -s <ID_EMULADOR_WEAR_OS> forward tcp:8080 tcp:8080

# Máquina host -> teléfono físico (localhost:8080 del teléfono llega a localhost:8080 del host)
adb -s <ID_TELEFONO_FISICO> reverse tcp:8080 tcp:8080
```

Con ambos comandos activos, el teléfono conectándose a `ws://127.0.0.1:8080`
llega en realidad al wearable emulado, a través de la PC.

## Cómo correr la práctica

1. Conecta el teléfono físico por USB con depuración habilitada y arranca
   el emulador de Wear OS (Large Round, API 33) desde Android Studio.
2. Identifica los IDs de ambos dispositivos:
   ```bash
   flutter devices
   ```
   Verás algo como `emulator-5554` (Wear OS) y el serial de tu teléfono
   (p.ej. `R58N...`).
3. Arma el túnel adb (ver comandos arriba) usando esos IDs.
4. Corre el wearable en el emulador:
   ```bash
   cd wearable_app
   flutter run -d emulator-5554
   ```
   Presiona **Iniciar**. Esto arranca el simulador de sensores, intenta el
   advertising BLE real y (siempre) levanta el WebSocket de respaldo.
5. Corre la app del teléfono en el dispositivo físico:
   ```bash
   cd telefono_app
   flutter run -d <ID_DEL_TELEFONO>
   ```
   Acepta los permisos de Bluetooth/ubicación cuando se pidan, y presiona
   **Buscar wearable**.
6. **Si el advertising BLE falla** (lo esperable en este entorno): a los
   ~15s la app cae sola al WebSocket. Si tampoco conecta por WebSocket,
   revisa que el túnel `adb forward`/`adb reverse` del paso 3 siga activo
   (se cae si desconectas el USB o reinicias el emulador) y presiona
   **Reintentar**.

## Dependencias añadidas fuera de la especificación original

- `wearable_app`: `bluetooth_low_energy` (servidor GATT real).
- `telefono_app`: `permission_handler` (pide `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT`
  en tiempo de ejecución en Android 12+) y `web_socket_channel` (cliente del
  transporte de respaldo).
