"""
getCellLabel - Generate a descriptive label for a battery cell based on the ageing test plan

This function takes a cell identifier and returns a formatted label containing
the temperature, charge C-rate, discharge C-rate, and test type.

Author: Converted from MATLAB to Python
Date: 2026-02-19
"""


def get_cell_label(cell_num):
    """
    Generate a descriptive label for a battery cell based on the ageing test plan.
    
    Parameters
    ----------
    cell_num : str
        Cell identifier string (e.g., 'A2.08_Cell_35' or 'A01_01')
    
    Returns
    -------
    label : str
        Formatted string with test conditions
    """
    
    # Extract temperature group and channel from cell_num
    # Supported formats:
    #   - 'A01_01' -> temp_group=1, channel=1
    #   - 'A2.08_Cell_35' -> temp_group=2, channel=8
    #   - 'A02_02' -> temp_group=2, channel=2
    
    if '_Cell_' in cell_num:
        # Format: A2.08_Cell_35
        parts = cell_num.split('_Cell_')
        condition_code = parts[0]
        dot_idx = condition_code.find('.')
        temp_group = int(condition_code[1:dot_idx])
        channel = int(condition_code[dot_idx+1:])
    else:
        # Format: A01_01 or A02_02
        parts = cell_num.split('_')
        condition_code = parts[0]  # e.g., 'A01'
        # temp_group is digits after 'A' (e.g., '01' -> 1)
        temp_group = int(condition_code[1:])
        # Channel is the second part
        channel = int(parts[1])
    
    # Define temperature based on group
    temp_map = {
        1: '0°C',
        2: '25°C',
        3: '45°C',
        4: '0-45°C'
    }
    temperature = temp_map.get(temp_group, 'Unknown')
    
    # Define test conditions based on temperature group and channel
    test_type, charge_rate, discharge_rate = _get_test_conditions(temp_group, channel)
    
    # Build label
    if not charge_rate and not discharge_rate:
        label = f'{temperature}, {test_type}'
    elif not charge_rate:
        label = f'{temperature}, {test_type}, Dch: {discharge_rate}C'
    elif not discharge_rate:
        label = f'{temperature}, {test_type}, Ch: {charge_rate}C'
    else:
        label = f'{temperature}, {test_type}, Ch: {charge_rate}C, Dch: {discharge_rate}C'
    
    return label


def _get_test_conditions(temp_group, channel):
    """
    Returns test conditions based on temperature group and channel number.
    
    Parameters
    ----------
    temp_group : int
        Temperature group (1-4)
    channel : int
        Channel number
    
    Returns
    -------
    test_type : str
        Type of test
    charge_rate : str
        Charge C-rate
    discharge_rate : str
        Discharge C-rate
    """
    
    # 0°C conditions
    conditions_1 = {
        1: ('Calendar', '', ''),
        2: ('CC cycle', '0.5', '0.5'),
        3: ('CC cycle', '0.25', '0.5'),
        4: ('CC cycle', '0.75', '0.5'),
        5: ('CC cycle', '1', '0.5'),
        6: ('CC cycle (var C-rate)', '0.25-1', '0.5'),
        7: ('EDF load cycle', '', ''),
        8: ('TOFAS drive cycle', '0.5', ''),
    }
    
    # 25°C conditions
    conditions_2 = {
        1: ('Calendar', '', ''),
        2: ('CC cycle 100% DoD', '0.5', '0.5'),
        3: ('CC cycle 10% DoD', '0.5', '0.5'),
        4: ('CC cycle 40% DoD', '0.5', '0.5'),
        5: ('CC cycle 70% DoD', '0.5', '0.5'),
        6: ('CC cycle', '1', '0.5'),
        7: ('CC cycle', '1.5', '0.5'),
        8: ('CC cycle', '2', '0.5'),
        9: ('CC cycle', '0.5', '1.5'),
        10: ('EDF load cycle', '', ''),
        11: ('TOFAS drive cycle', '0.5', ''),
    }
    
    # 45°C conditions
    conditions_3 = {
        1: ('Calendar 10% SoC', '', ''),
        2: ('Calendar 50% SoC', '', ''),
        3: ('Calendar 100% SoC', '', ''),
        4: ('CC cycle 100% DoD', '0.5', '0.5'),
        5: ('CC cycle 50% DoD @75% SoC', '0.5', '0.5'),
        6: ('CC cycle 50% DoD @25% SoC', '0.5', '0.5'),
        7: ('CC cycle 50% DoD @50% SoC', '0.5', '0.5'),
        8: ('CC cycle', '1', '0.5'),
        9: ('CC cycle 4.45V', '1', '0.5'),
        10: ('CCCV cycle 4.45V', '1', '0.5'),
        11: ('CC cycle', '0.5', '1'),
        12: ('CC cycle', '1', '1'),
        13: ('EDF load cycle', '', ''),
        14: ('TOFAS drive cycle', '0.5', ''),
    }
    
    # 0-45°C Dynamic conditions
    conditions_4 = {
        1: ('CC cycle', '0.5', '0.5'),
        2: ('EDF load cycle', '', ''),
        3: ('TOFAS drive cycle', '0.5', ''),
        4: ('Mixed TOFAS/EDF', '0.5', ''),
        5: ('TOFAS+EDF', '0.5', ''),
    }
    
    conditions_map = {
        1: conditions_1,
        2: conditions_2,
        3: conditions_3,
        4: conditions_4,
    }
    
    conditions = conditions_map.get(temp_group, {})
    return conditions.get(channel, ('Unknown', '', ''))


# For compatibility with import statement
__all__ = ['get_cell_label']
