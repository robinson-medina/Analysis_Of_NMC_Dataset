"""
exportOCPDischarge - Export flattened OCP discharge data to CSV

Converts cell-wise OCP/SoC data structures into a flattened CSV file with
appropriately repeated capacity and timestamp columns for each checkup.

Author: Converted from MATLAB to Python
Date: 2026-04-14
"""

import os
import pandas as pd


def export_ocp_discharge(save_path, cell_num, checkup_soc, checkup_ocv_v, checkup_capacity_ah, checkup_capacity_timestamp):
    """
    Export flattened OCP discharge data to CSV.
    
    Creates one CSV with columns:
      1) CheckUpSoC - State of Charge
      2) CheckUpOCV_V - Open Circuit Voltage 
      3) CheckupCapacity_Ah - Cell capacity (repeated for each SoC point in checkup)
      4) CheckupCapacityTimeStamp - Timestamp (repeated for each SoC point in checkup)
    
    Parameters
    ----------
    save_path : str
        Directory path where CSV will be saved
    cell_num : str
        Cell identifier (used in filename)
    checkup_soc : list
        List of SoC arrays, one per checkup
    checkup_ocv_v : list
        List of OCV voltage arrays, one per checkup
    checkup_capacity_ah : list
        List of capacity values, one per checkup
    checkup_capacity_timestamp : list or pd.DatetimeIndex
        List of timestamps, one per checkup
    
    Returns
    -------
    ocp_csv_path : str
        Full path to the generated CSV file
    """
    
    ocp_soc_all = []
    ocp_v_all = []
    ocp_cap_all = []
    ocp_ts_all = []
    
    num_checkups = min([
        len(checkup_soc),
        len(checkup_ocv_v),
        len(checkup_capacity_ah),
        len(checkup_capacity_timestamp)
    ])
    
    for checkup_idx in range(num_checkups):
        soc_vec = checkup_soc[checkup_idx]
        ocv_vec = checkup_ocv_v[checkup_idx]
        
        # Skip empty checkups
        if soc_vec is None or ocv_vec is None or len(soc_vec) == 0 or len(ocv_vec) == 0:
            continue
        
        # Match number of points to minimum available
        n_points = min(len(soc_vec), len(ocv_vec))
        
        # Extend output arrays
        ocp_soc_all.extend(soc_vec[:n_points])
        ocp_v_all.extend(ocv_vec[:n_points])
        ocp_cap_all.extend([checkup_capacity_ah[checkup_idx]] * n_points)
        ocp_ts_all.extend([checkup_capacity_timestamp[checkup_idx]] * n_points)
    
    # Create safe filename (replace unsafe characters)
    safe_cell_num = ''.join(c if c.isalnum() or c in '_-' else '_' for c in cell_num)
    ocp_csv_name = f'OCPDis_{safe_cell_num}.csv'
    ocp_csv_path = os.path.join(save_path, ocp_csv_name)
    
    # Create and save DataFrame
    if len(ocp_soc_all) > 0:
        ocp_table = pd.DataFrame({
            'CheckUpSoC': ocp_soc_all,
            'CheckUpOCV_V': ocp_v_all,
            'CheckupCapacity_Ah': ocp_cap_all,
            'CheckupCapacityTimeStamp': ocp_ts_all
        })
        ocp_table.to_csv(ocp_csv_path, index=False)
        print(f"OCP discharge data exported to: {ocp_csv_path}")
    else:
        print(f"Warning: No valid OCP data to export for cell {cell_num}")
    
    return ocp_csv_path
