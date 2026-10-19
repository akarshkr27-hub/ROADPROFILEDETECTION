import time
from pathlib import Path
from datetime import datetime

import joblib
import numpy as np
import pandas as pd
import plotly.express as px
import streamlit as st
import serial
from serial.tools import list_ports

DATA_DIR = Path("data")
DATA_FILE = DATA_DIR / "road_data.csv"
MODEL_FILE = DATA_DIR / "road_model.joblib"

st.set_page_config(
    page_title="AI Road Profile Detection",
    page_icon="🚗",
    layout="wide"
)


def extract_features(values):
    values = np.asarray(values, dtype=float)

    return [[
        float(np.mean(values)),
        float(np.std(values)),
        float(np.min(values)),
        float(np.max(values)),
        float(np.max(values) - np.min(values)),
        float(values[-1] - values[0]),
        float(np.polyfit(np.arange(len(values)), values, 1)[0])
    ]]


def available_ports():
    return [p.device for p in list_ports.comports()]


def read_live_data(port, seconds=5):
    readings = []
    end_time = time.time() + seconds

    with serial.Serial(port, 115200, timeout=0.2) as ser:
        time.sleep(2)
        ser.reset_input_buffer()

        while time.time() < end_time:
            line = ser.readline().decode(
                "utf-8", errors="ignore"
            ).strip()

            parts = line.split(",")

            if len(parts) != 4:
                continue

            try:
                time_ms = int(parts[0])
                raw = int(parts[1])
                voltage = float(parts[2])
                distance = float(parts[3])
            except ValueError:
                continue

            if 0 < distance < 100:
                readings.append({
                    "timestamp": datetime.now().isoformat(
                        timespec="milliseconds"
                    ),
                    "time_ms": time_ms,
                    "raw": raw,
                    "voltage": voltage,
                    "distance_cm": distance
                })

    return pd.DataFrame(readings)


st.title("AI-Based Road Profile Detection")
st.caption(
    "Infrared sensing • Machine learning • Real-time monitoring"
)

mode = st.radio(
    "Operating mode",
    ["Demo mode", "Live sensor mode"],
    horizontal=True
)

st.divider()

if mode == "Demo mode":
    st.info(
        "Demo data only. These readings are simulated and do not "
        "represent real sensor measurements or validated predictions."
    )

    df = pd.DataFrame({
        "Reading": range(1, 31),
        "Distance (cm)": [
            20, 20, 20, 20, 19.9, 20.1, 20, 19.8, 20, 20.1,
            19.9, 19.8, 17, 15, 13, 12, 13, 15, 17, 19,
            20, 20, 20.1, 19.9, 20, 20, 20.1, 20, 19.9, 20
        ]
    })

    c1, c2, c3 = st.columns(3)
    c1.metric("Latest distance", f"{df['Distance (cm)'].iloc[-1]:.2f} cm")
    c2.metric("Readings shown", len(df))
    c3.metric("Connection", "Demo")

    fig = px.line(
        df,
        x="Reading",
        y="Distance (cm)",
        markers=True,
        title="Simulated Distance Measurements"
    )
    st.plotly_chart(fig, use_container_width=True)

    st.subheader("AI prediction")
    st.write("No prediction: simulated data is not automatically classified.")

    st.download_button(
        "Download demo readings",
        df.to_csv(index=False).encode("utf-8"),
        "demo_readings.csv",
        "text/csv"
    )

else:
    ports = available_ports()

    if not ports:
        st.warning(
            "No serial port detected. Connect the ESP32, "
            "check its driver, and close Arduino Serial Monitor."
        )
    else:
        port = st.selectbox("ESP32 serial port", ports)
        duration = st.slider(
            "Capture duration (seconds)", 3, 15, 5
        )

        if st.button("Capture sensor readings"):
            try:
                with st.spinner("Reading sensor data..."):
                    df = read_live_data(port, duration)

                if df.empty:
                    st.error(
                        "No valid readings received. Check the wiring, "
                        "baud rate and ESP32 serial output."
                    )
                else:
                    st.session_state["live_df"] = df

                    DATA_DIR.mkdir(exist_ok=True)
                    df.to_csv(
                        DATA_DIR / "latest_capture.csv",
                        index=False
                    )

            except (serial.SerialException, OSError) as exc:
                st.error(f"Serial connection failed: {exc}")

        df = st.session_state.get("live_df")

        if df is not None and not df.empty:
            c1, c2, c3 = st.columns(3)
            c1.metric(
                "Latest distance",
                f"{df['distance_cm'].iloc[-1]:.2f} cm"
            )
            c2.metric("Valid readings", len(df))
            c3.metric("Connection", "Captured")

            fig = px.line(
                df.reset_index(),
                x="index",
                y="distance_cm",
                markers=True,
                title="Live Sensor Capture"
            )
            fig.update_layout(
                xaxis_title="Reading",
                yaxis_title="Distance (cm)"
            )
            st.plotly_chart(fig, use_container_width=True)

            if MODEL_FILE.exists():
                bundle = joblib.load(MODEL_FILE)
                window_size = bundle["window_size"]

                if len(df) >= window_size:
                    values = df["distance_cm"].tail(
                        window_size
                    ).to_numpy()

                    features = extract_features(values)
                    model = bundle["model"]
                    prediction = model.predict(features)[0]

                    st.subheader("Model prediction")
                    st.success(f"Predicted class: {prediction}")

                    if hasattr(model, "predict_proba"):
                        probabilities = model.predict_proba(features)[0]
                        confidence = float(np.max(probabilities))

                        st.metric(
                            "Model confidence",
                            f"{confidence * 100:.1f}%"
                        )

                        st.caption(
                            "Model confidence is not a guarantee "
                            "of prediction correctness."
                        )
                else:
                    st.info(
                        f"Collect at least {window_size} valid readings "
                        "for a prediction."
                    )
            else:
                st.warning(
                    "AI model not found. Collect labelled data and "
                    "run train_model.py first."
                )

            st.download_button(
                "Download captured readings",
                df.to_csv(index=False).encode("utf-8"),
                "captured_readings.csv",
                "text/csv"
            )

st.divider()
st.caption(
    "Research prototype only. Predictions require calibration and "
    "validation; do not use this system for vehicle safety decisions."
)
