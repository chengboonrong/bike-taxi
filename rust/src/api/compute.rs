/// Flat latitude/longitude pairs. No platform APIs or Firestore access.
#[flutter_rust_bridge::frb(sync)]
pub fn decode_polyline(encoded: String, precision: u8) -> Result<Vec<f64>, String> {
    if precision != 5 && precision != 6 {
        return Err("precision must be 5 or 6".into());
    }
    let factor = if precision == 5 { 100_000 } else { 1_000_000 };
    let bytes = encoded.as_bytes();
    let mut index = 0;
    let (mut lat, mut lon) = (0_i64, 0_i64);
    let mut points = Vec::new();
    while index < bytes.len() {
        lat += next_delta(bytes, &mut index)?;
        lon += next_delta(bytes, &mut index)?;
        if lat.abs() > 90 * factor || lon.abs() > 180 * factor {
            return Err("coordinate out of range".into());
        }
        points.push(lat as f64 / factor as f64);
        points.push(lon as f64 / factor as f64);
    }
    Ok(points)
}

fn next_delta(bytes: &[u8], index: &mut usize) -> Result<i64, String> {
    let mut value = 0_i64;
    for shift in (0..30).step_by(5) {
        let byte = *bytes.get(*index).ok_or("truncated polyline")?;
        *index += 1;
        if !(63..=126).contains(&byte) {
            return Err("invalid polyline character".into());
        }
        let chunk = byte - 63;
        value |= i64::from(chunk & 31) << shift;
        if chunk < 32 {
            return Ok(if value & 1 == 1 {
                !(value >> 1)
            } else {
                value >> 1
            });
        }
    }
    Err("polyline component too long".into())
}

/// Preserve Dart's operation order, half-away-from-zero rounding and i64 saturation.
/// This client-side estimate is not trusted fare enforcement.
#[flutter_rust_bridge::frb(sync)]
pub fn fare_for(km: f64) -> Result<f64, String> {
    let tenths = ((2.5 + 1.5 * km * 0.621371) * 10.0).round();
    if !tenths.is_finite() {
        return Err("non-finite fare".into());
    }
    Ok((tenths as i64) as f64 / 10.0)
}
