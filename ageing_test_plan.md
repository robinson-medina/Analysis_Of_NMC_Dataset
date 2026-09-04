# Ageing Test Plan

Naming convention: **`Cell_<n>`** — just the physical cell number `n`, no
campaign letter or temperature prefix. The channel was internal and is retained
only as a channel-to-cell crosswalk.

Cell numbers were verified against the `4_Ageing` calendar/cyclic ageing folder
names and the `CellNum` / `CellLabel` columns of `OverviewCapacityData_36cell.csv` and
`OverviewCapacityData_5cell.csv`, which are the authoritative source.

## 0°C
| Channel | ID | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|
| 1 | Cell_57 | Calendar ageing | 0% (4.35V) | 1 | 0 | 0 |  |
| 2 | Cell_60 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Monitor effect of Temp |
| 3 | Cell_63 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.25 | 0.5 | Monitor effect of C-rate |
| 4 | Cell_66 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.75 | 0.5 | Monitor effect of C-rate |
| 5 | Cell_68 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 0.5 | Monitor effect of C-rate |
| 6 | Cell_71 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | [0.25, 0.5, 0.75, 1] | 0.5 | Monitor effect of C-rate variations |
| 7 | Cell_74 | Load cycle | | 0.5 | | | Validation (stationary-storage profile) |
| 8 | Cell_72 | Drive cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | | Validation (automotive profile) |

Channels 4–8 (Cell_66, Cell_71, Cell_72, Cell_74) were stopped after middle-of-life
and reused to run the three 25 °C consistency replicates (Cell_56, Cell_89, Cell_93).

## 25°C
| Channel | ID | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|
| 1 | Cell_11 | Calendar ageing | 0% (4.35V) | 1 | 0 | 0 |  |
| 2 | Cell_12 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Monitor effect of Temp (baseline) |
| 2r | Cell_56 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Consistency replicate of Cell_12 (from MoL; reused 0 °C channel) |
| 2r | Cell_89 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Consistency replicate of Cell_12 (from MoL; reused 0 °C channel) |
| 2r | Cell_93 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Consistency replicate of Cell_12 (from MoL; reused 0 °C channel) |
| 3 | Cell_16 | CC cycle | 10%: (3.676V-3.747V) | 0.5 | 0.5 | 0.5 | Monitor effect of DoD |
| 4 | Cell_30 | CC cycle | 40%: (3.617V-3.936V) | 0.5 | 0.5 | 0.5 | Monitor effect of DoD |
| 5 | Cell_27 | CC cycle | 70%: (3.511V-4.120V) | 0.5 | 0.5 | 0.5 | Monitor effect of DoD |
| 6 | Cell_23 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 0.5 | Monitor effect of C-rate |
| 7 | Cell_34 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1.5 | 0.5 | Monitor effect of C-rate |
| 8 | Cell_35 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 2 | 0.5 | Monitor effect of C-rate |
| 9 | Cell_43 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 1.5 | Monitor effect of C-rate (asymmetric) |
| 10 | Cell_46 | Load cycle | | 0.5 | | | Validation (stationary-storage profile) |
| 11 | Cell_42 | Drive cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | | Validation (automotive profile) |

## 45°C
| Channel | ID | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|
| 1 | Cell_45 | Calendar ageing | 0% (3.474V) | 0.1 | 0 | 0 | Monitor effect of SOC |
| 2 | Cell_26 | Calendar ageing | 0% (3.706V) | 0.5 | 0 | 0 | Monitor effect of SOC |
| 3 | Cell_28 | Calendar ageing | 0% (4.35V) | 1 | 0 | 0 | Monitor effect of SOC |
| 4 | Cell_29 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Monitor effect of Temp |
| 5 | Cell_40 | CC cycle | 50%: (3.706V-4.35V) | 0.75 | 0.5 | 0.5 | Monitor effect of avg SoC |
| 6 | Cell_1 | CC cycle | 50%: (2.75V-3.706V) | 0.25 | 0.5 | 0.5 | Monitor effect of avg SoC |
| 7 | Cell_3 | CC cycle | 50%: (3.587V-3.999V) | 0.5 | 0.5 | 0.5 | Monitor effect of avg SoC |
| 8 | Cell_9 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 0.5 | Monitor effect of C-rate |
| 9 | Cell_5 | CC cycle | 100%: (2.75V-4.45V) | 0.5 | 1 | 0.5 | Monitor effect of high voltage levels |
| 10 | Cell_22 | CCCV charge & CC cycle | 100%: (2.75V-4.45V) | 0.5 | 1 | 0.5 | Monitor effect of high voltage levels (torn down post-mortem) |
| 11 | Cell_8 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 1 | Monitor effect of C-rate (asymmetric) |
| 12 | Cell_47 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 1 | Monitor effect of C-rate |
| 13 | Cell_17 | Load cycle | | 0.5 | | | Validation (stationary-storage profile) |
| 14 | Cell_25 | Drive cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | | Validation (automotive profile) |

## 0°C – 45°C (Dynamic Temperature)
| Channel | ID | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|
| 1 | Cell_49 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Reference conditions |
| 2 | Cell_50 | Load cycle | | 0.5 | | | Validation (stationary-storage profile) |
| 3 | Cell_53 | Drive cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | | Validation (automotive profile) |
| 4 | Cell_64 | Mixed: auto 1–4 m, stat 5–6 m, auto 7–8 m, stat 9–12 m | 100%: (2.75V-4.35V) | 0.5 | 0.5 | | Validation |
| 5 | Cell_70 | Mixed: auto 1–6 m, stat 7–12 m | 100%: (2.75V-4.35V) | 0.5 | 0.5 | | Validation |

## Test Parameters Legend

- **DoD**: Depth of Discharge (voltage-based)
- **Average SoC**: Average State of Charge during cycling
- **Charge/Discharge**: C-rate for charging/discharging (e.g., 0.5 = 0.5C, 1 = 1C)
- **CC cycle**: Constant Current cycling
- **CCCV**: Constant Current Constant Voltage charging
- **Load cycle**: stationary-storage dynamic profile
- **Drive cycle**: automotive dynamic profile
- **stat. / auto.**: stationary-storage / automotive profile (used in the figure)
