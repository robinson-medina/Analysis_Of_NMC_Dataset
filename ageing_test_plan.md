# Ageing Test Plan

## 0°C 
| Channel | Cell name | Cell number | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|---|
| 1 | A01_01 | Cell_57 | Calendar ageing | 0% (4.35V) | 1 | 0 | 0 |  |
| 2 | A01_02 | Cell_60 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Monitor effect of Temp |
| 3 | A01_03 | Cell_63 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.25 | 0.5 | Monitor effect of C-rate |
| 4 | A01_04 | Cell_66 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.75 | 0.5 | Monitor effect of C-rate |
| 5 | A01_05 | Cell_68 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 0.5 | Monitor effect of C-rate |
| 6 | A01_06 | Cell_71 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | [0.25, 0.5, 0.75, 1] | 0.5 | Monitor effect of C-rate variations |
| 7 | A01_07 | Cell_74 | Load cycle  |  | 0.5 |  |  | Validation - stationary storage cycle|
| 8 | A01_08 | Cell_72 | Drive cycle  | 100%: (2.75V-4.35V) | 0.5 | 0.5 |  | Validation |

## 25°C 
| Channel | Cell name | Cell number | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|---|
| 1 | A02_01 | Cell_11 | Calendar ageing | 0% (4.35V) | 1 | 0 | 0 |  |
| 2 | A02_02 | Cell_12 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Monitor effect of Temp |
| 3 | A02_03 | Cell_16 | CC cycle | 10%: (3.676V-3.747V) | 0.5 | 0.5 | 0.5 | Monitor effect of DoD |
| 4 | A02_04 | Cell_30 | CC cycle | 40%: (3.617V-3.936V) | 0.5 | 0.5 | 0.5 | Monitor effect of DoD |
| 5 | A02_05 | Cell_27 | CC cycle | 70%: (3.511V-4.120V) | 0.5 | 0.5 | 0.5 | Monitor effect of DoD |
| 6 | A02_06 | Cell_23 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 0.5 | Monitor effect of C-rate |
| 7 | A02_07 | Cell_34 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1.5 | 0.5 | Monitor effect of C-rate |
| 8 | A02_08 | Cell_35 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 2 | 0.5 | Monitor effect of C-rate |
| 9 | A02_09 | Cell_43 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 1.5 | Monitor effect of C-rate |
| 10 | A02_10 | Cell_46 | Load cycle  |  | 0.5 |  |  | Validation - stationary storage cycle|
| 11 | A02_11 | Cell_42 | Drive cycle  | 100%: (2.75V-4.35V) | 0.5 | 0.5 |  | Validation |

## 45°C 
| Channel | Cell name | Cell number | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|---|
| 1 | A03_01 | Cell_45 | Calendar ageing | 0% (3.474V) | 0.1 | 0 | 0 | Monitor effect of SOC |
| 2 | A03_02 | Cell_26 | Calendar ageing | 0% (3.706V) | 0.5 | 0 | 0 | Monitor effect of SOC |
| 3 | A03_03 | Cell_28 | Calendar ageing | 0% (4.35V) | 1 | 0 | 0 | Monitor effect of SOC |
| 4 | A03_04 | Cell_29 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Monitor effect of Temp |
| 5 | A03_05 | Cell_40 | CC cycle | 50%: (3.706V-4.35V) | 0.75 | 0.5 | 0.5 | Monitor effect of avg SoC |
| 6 | A03_06 | Cell_1 | CC cycle | 50%: (2.75V-3.706V) | 0.25 | 0.5 | 0.5 | Monitor effect of avg SoC |
| 7 | A03_07 | Cell_3 | CC cycle | 50%: (3.587V-3.999V) | 0.5 | 0.5 | 0.5 | Monitor effect of avg SoC |
| 8 | A03_08 | Cell_8 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 0.5 | Monitor effect of C-rate |
| 9 | A03_09 | Cell_9 | CC cycle | 100%: (2.75V-4.45V) | 0.5 | 1 | 0.5 | Monitor effect of high voltage levels |
| 10 | A03_10 | Cell_22 | CCCV charge & CC cycle | 100%: (2.75V-4.45V) | 0.5 | 1 | 0.5 | Monitor effect of high voltage levels |
| 11 | A03_11 | Cell_47 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 1 | Monitor effect of C-rate |
| 12 | A03_12 | Cell_5 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 1 | 1 | Monitor effect of C-rate |
| 13 | A03_13 | Cell_17 | Load cycle  |  | 0.5 |  |  | Validation - stationary storage cycle |
| 14 | A03_14 | Cell_25 | Drive cycle  | 100%: (2.75V-4.35V) | 0.5 | 0.5 |  | Validation |

## 0°C – 45°C (Dynamic Temperature)
| Channel | Cell name | Cell number | Type | DoD (V-based) | Average SoC | Charge | Discharge | Effect |
|---|---|---|---|---|---|---|---|---|
| 1 | A04_01 | Cell_50 | CC cycle | 100%: (2.75V-4.35V) | 0.5 | 0.5 | 0.5 | Reference conditions |
| 2 | A04_02 | Cell_51 | Load cycle  |  | 0.5 |  |  | Validation |
| 3 | A04_03 | Cell_52 | Drive cycle  | 100%: (2.75V-4.35V) | 0.5 | 0.5 |  | Validation - stationary storage cycle|
| 4 | A04_04 | Cell_53 | TOFAS 1 (1-2m) - TOFAS 2 (3-4m) - EDF 1 (5-6m) - TOFAS 1 (7-8m) - EDF 2 (9-12m) | 100%: (2.75V-4.35V) | 0.5 | 0.5 |  | Validation |
| 5 | A04_05 | Cell_54 | TOFAS 1 (1-6m) - EDF 1 (7-12m) | 100%: (2.75V-4.35V) | 0.5 | 0.5 |  | Validation |

## Test Parameters Legend

- **DoD**: Depth of Discharge (voltage-based)
- **Average SoC**: Average State of Charge during cycling
- **Charge/Discharge**: C-rate for charging/discharging (e.g., 0.5 = 0.5C, 1 = 1C)
- **CC cycle**: Constant Current cycling
- **CCCV**: Constant Current Constant Voltage charging
- **EDF**: Load cycle profile from EDF
- **TOFAS**: Drive cycle profile from TOFAS
