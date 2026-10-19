# Road Profile Detection Using Infrared Sensors

An embedded optoelectronic sensing system that detects road surface anomalies—including speed bumps, potholes/dips, and rough patches—in real time[cite: 1, 2]. Built around a **940 nm** infrared (IR) emitter and photodiode pair, an **LM358** active low-pass filter, and an **ESP32** microcontroller, the module measures vertical clearance variations via diffuse optical reflectance, triggers immediate visual LED speed advisories, and streams structured CSV telemetry to a host computer at **115200 baud**[cite: 1, 2].

---

## Key Features

* **Non-Contact Optoelectronic Profiling:** Utilizes a matched **940 nm** IR LED emitter and reverse-biased PIN photodiode housed in an optical isolation shroud to continuously measure surface reflectance across a miniature test track[cite: 1, 2].
* **Hardware Signal Conditioning:** Incorporates an **LM358** operational amplifier configured as an active low-pass filter with a **100 kΩ** transimpedance load, **10 nF** input filter, and **330 nF** / **1 kΩ** feedback network to attenuate high-frequency mechanical vibration noise before analog-to-digital conversion[cite: 1, 2].
* **Real-Time Embedded DSP Pipeline:** Samples conditioned analog voltages on the ESP32 12-bit SAR ADC (`GPIO 34`) at **200 Hz**, applying an Exponential Moving Average (EMA) low-pass filter alongside a rolling-window standard deviation ($\sigma$) calculation to separate discrete elevation changes from continuous rough textures[cite: 1].
* **One-Touch Baseline Auto-Calibration:** Includes an active-LOW hardware push button (`GPIO 4`) with a **10 kΩ** pull-up resistor to zero the reference flat-road voltage on any track surface[cite: 1, 2].
* **Three-Tier Visual Speed Advisory:** Drives dedicated Green (`GPIO 25`), Amber (`GPIO 26`), and Red (`GPIO 27`) indicator LEDs through **220 Ω** current-limiting resistors to signal nominal cruise speed, caution (dip or rough surface), and hazard (speed bump) states[cite: 1, 2].
* **Automated CSV Telemetry & 3D CAD Package:** Streams time-series measurements over USB Serial to a companion Python logger and includes full 2D schematics, parametric OpenSCAD scripts, interactive WebGL STL viewers, and ISO 10303 `.STEP` CAD models[cite: 1, 2].

---

## Hardware Architecture & Bill of Materials (BOM)

The physical assembly is laid out on a **100 mm × 65 mm × 1.6 mm** 2-layer FR4 Printed Circuit Board (PCB) featuring four corner M3 mounting holes[cite: 2].

| Designator | Component | Value / Specification | Schematic Block |
| --- | --- | --- | --- |
| **MCU** | ESP32 DevKit V1 | `ESP32-WROOM-32` (3.3 V logic, 12-bit ADC) | Microcontroller Core[cite: 1, 2] |
| **D1** | IR Emitter LED | **940 nm** wavelength, 5 mm radial package | Optical Front-End[cite: 1, 2] |
| **D2** | IR Photodiode | **940 nm** silicon PIN photodiode, 5 mm radial | Optical Front-End[cite: 1, 2] |
| **U1** | LM358 | Dual Operational Amplifier (DIP-8 package) | Signal Conditioning & Active LPF[cite: 1, 2] |
| **BTN1** | Tactile Push Button | 6 mm × 6 mm momentary switch (Active LOW) | Calibration & Input[cite: 1, 2] |
| **LED1** | Green LED | 5 mm through-hole (`FLAT` / Nominal Speed) | Speed Advisory LEDs[cite: 1, 2] |
| **LED2** | Amber LED | 5 mm through-hole (`DIP` / `ROUGH` Caution) | Speed Advisory LEDs[cite: 1, 2] |
| **LED3** | Red LED | 5 mm through-hole (`BUMP` / Hazard) | Speed Advisory LEDs[cite: 1, 2] |
| **R1** | Axial Resistor | **150 Ω** (0.25 W) — IR LED current limiter | Optical Front-End[cite: 1, 2] |
| **R2** | Axial Resistor | **100 kΩ** (0.25 W) — Photodiode pull-down load | Optical Front-End[cite: 1, 2] |
| **R4** | Axial Resistor | **1 kΩ** (0.25 W) — Op-amp LPF feedback | Signal Conditioning & Active LPF[cite: 1, 2] |
| **R5** | Axial Resistor | **10 kΩ** (0.25 W) — Calibration button pull-up | Calibration & Input[cite: 1, 2] |
| **R6, R7, R8** | Axial Resistors (3×) | **220 Ω** (0.25 W) — LED current limiters | Speed Advisory LEDs[cite: 1, 2] |
| **C1** | Ceramic Capacitor | **10 nF** — Photodiode input noise decoupling | Optical Front-End[cite: 1, 2] |
| **C2** | Film/Ceramic Capacitor | **330 nF** — Active low-pass filter capacitor | Signal Conditioning & Active LPF[cite: 1, 2] |
| **C3** | Ceramic Capacitor | **100 nF** — ESP32 `3V3` rail decoupling | ESP32 Dev Module[cite: 1, 2] |

---

## ESP32 Pinout Mapping

| ESP32 Pin | Hardware Net | Direction | Function |
| --- | --- | --- | --- |
| `3V3` | `+3.3V` Power Rail | Output | Powers optical front-end, LM358 (`Pin 8`), and pull-up[cite: 1] |
| `GND` | Common Ground | Ground | Common return path decoupled via `C3` (**100 nF**)[cite: 1, 2] |
| `GPIO 34` (`ADC1_CH6`) | `V_ADC` (`U1 Pin 1`) | Input (Analog) | Reads conditioned IR reflectance voltage (**0–3.3 V**)[cite: 1] |
| `GPIO 4` | `BTN1` & `R5` Junction | Input (Digital) | Triggers flat-road baseline recalibration when pulled `LOW`[cite: 1, 2] |
| `GPIO 25` | `R6` → `LED1` (Green) | Output (Digital) | Illuminates for nominal flat road profile[cite: 1, 2] |
| `GPIO 26` | `R7` → `LED2` (Amber) | Output (Digital) | Solid for Dip/Pothole; 8 Hz strobe for Rough Patch[cite: 1, 2] |
| `GPIO 27` | `R8` → `LED3` (Red) | Output (Digital) | Illuminates for Speed Bump hazard[cite: 1, 2] |
| `USB` | UART0 Serial (`TX`/`RX`) | Bidirectional | Streams CSV telemetry to PC at **115200 baud**[cite: 1, 2] |

---

## Signal Processing & Classification Logic

1. **Exponential Moving Average (EMA) Filtering:**
Raw millivolt readings $V_{raw}[n]$ from `analogReadMilliVolts(34)` are smoothed at **200 Hz** using a recursive first-order low-pass filter ($\alpha = 0.25$):

$$V_{filt}[n] = \alpha \cdot V_{raw}[n] + (1 - \alpha) \cdot V_{filt}[n - 1]$$


2. **Rolling Standard Deviation ($\sigma$) for Roughness:**
Across a sliding window of $N = 20$ samples (**100 ms** window), the firmware computes the sample mean $\mu$ and standard deviation $\sigma$ to quantify high-frequency surface texture:

$$\sigma = \sqrt{\frac{1}{N}\sum_{i=1}^{N} \left(V_{filt}[i] - \mu\right)^2}$$


3. **Multi-Threshold Profile Classification:**
Using the calibrated flat-road baseline $V_{base}$, the firmware evaluates the voltage deviation $\Delta V = V_{filt} - V_{base}$ and rolling roughness $\sigma$:

| Classified State | Decision Criterion | Physical Condition | LED Indicator | Speed Advisory |
| --- | --- | --- | --- | --- |
| `FLAT` | $\lvert\Delta V\rvert < 350\text{ mV}$ and $\sigma < 120\text{ mV}$ | Nominal baseline clearance | **Green LED (ON)**[cite: 1, 2] | **60 km/h** (Nominal) |
| `BUMP` | $\Delta V \ge +350\text{ mV}$ | Decreased clearance / raised crest | **Red LED (ON)**[cite: 1, 2] | **15 km/h** (Hazard) |
| `DIP` | $\Delta V \le -350\text{ mV}$ | Increased clearance / pothole | **Amber LED (Solid)**[cite: 1, 2] | **25 km/h** (Caution) |
| `ROUGH` | $\sigma \ge 120\text{ mV}$ and $\lvert\Delta V\rvert < 350\text{ mV}$ | Rapid oscillation / coarse patch | **Amber LED (8 Hz Blink)** | **30 km/h** (Caution) |

---

## Repository Structure

```text
road-profile-detection-ir/
├── firmware/
│   └── RoadProfileDetector/
│       └── RoadProfileDetector.ino    # ESP32 Arduino C++ firmware (200 Hz DSP & CSV logger)
├── software/
│   └── serial_to_csv.py               # Python PySerial telemetry logger & CSV exporter
├── hardware/
│   ├── schematic_2d.png               # 2D electronic circuit schematic
│   ├── pcb_3d_render.png              # 3D PCB assembly render
│   └── cad/
│       ├── road_profile_cad.html      # Interactive 3D WebGL viewer & binary .STL exporter
│       ├── road_profile_module.scad   # Parametric OpenSCAD 3D solid script
│       └── export_step.py             # CadQuery script to generate ISO 10303 .STEP files
├── data/
│   └── sample_track_run.csv           # Sample recorded CSV telemetry dataset
└── README.md                          # Project documentation

```

---

## Getting Started

### 1. Flash the ESP32 Firmware

1. Install the **Arduino IDE** (v2.x+) and add the **esp32 by Espressif Systems** board package via the Boards Manager.
2. Open `firmware/RoadProfileDetector/RoadProfileDetector.ino`.
3. Select **ESP32 Dev Module** under `Tools -> Board` and choose your COM port.
4. Place the sensor carriage over a flat section of the miniature track and click **Upload**. On boot, all three LEDs illuminate for **1 second** while the ESP32 averages 200 samples to lock in the flat-road baseline.

### 2. Run the Computer CSV Data Logger

1. Install Python 3 and the `pyserial` package:
```bash
pip install pyserial

```


2. Update `SERIAL_PORT` in `software/serial_to_csv.py` to match your system (e.g., `'COM3'` on Windows or `'/dev/ttyUSB0'` on Linux/macOS) and run:
```bash
python software/serial_to_csv.py

```


3. Move the sensor module along the miniature track. Press `Ctrl+C` to finish logging and save the timestamped `.csv` file.



## Sample CSV Output

```csv
timestamp_ms,raw_mv,filtered_mv,baseline_mv,delta_mv,roughness_sd_mv,profile_class,advisory_speed_kmh
1020,1648,1650.2,1650.0,0.2,4.1,FLAT,60
1080,2290,2180.4,1650.0,530.4,115.2,BUMP,15
1140,1120,1210.5,1650.0,-439.5,95.0,DIP,25
1160,1890,1710.2,1650.0,60.2,168.4,ROUGH,30

```

---

## License

This project is released under the **MIT License**. See the `LICENSE` file for details.
