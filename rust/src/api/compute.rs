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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_coordinates_and_limits() {
        assert!(decode_polyline("".into(), 6).unwrap().is_empty());
        assert_eq!(decode_polyline("????".into(), 6).unwrap(), vec![0.0; 4]);
        assert_eq!(
            decode_polyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@".into(), 5).unwrap(),
            vec![38.5, -120.2, 40.7, -120.95, 43.252, -126.453]
        );
    }

    #[test]
    fn malformed_input_is_an_error() {
        for (text, message) in [
            ("?", "truncated polyline"),
            ("_", "truncated polyline"),
            ("<?", "invalid polyline character"),
            ("\u{7f}?", "invalid polyline character"),
            ("é?", "invalid polyline character"),
            ("______?", "polyline component too long"),
            ("~~~~~~?", "polyline component too long"),
            ("~~~~~^?", "coordinate out of range"),
        ] {
            assert_eq!(decode_polyline(text.into(), 6).unwrap_err(), message);
        }
        assert_eq!(
            decode_polyline("".into(), 4).unwrap_err(),
            "precision must be 5 or 6"
        );
        // Exhaust short inputs at the trust boundary; none may panic.
        for a in 0..=127_u8 {
            for b in 0..=127_u8 {
                let _ = decode_polyline(String::from_utf8(vec![a, b]).unwrap(), 6);
            }
        }
    }

    #[test]
    fn captured_routes_are_repeatable() {
        let fixture: serde_json::Value =
            serde_json::from_str(include_str!("../../../test/fixtures/compute.json")).unwrap();
        for route in fixture["routes"].as_array().unwrap() {
            let decode = || {
                decode_polyline(
                    route["encoded"].as_str().unwrap().into(),
                    route["precision"].as_u64().unwrap() as u8,
                )
                .unwrap()
            };
            let points = decode();
            assert_eq!(
                points.len(),
                route["pointCount"].as_u64().unwrap() as usize * 2
            );
            assert_eq!(
                &points[..2],
                &[
                    route["first"][0].as_f64().unwrap(),
                    route["first"][1].as_f64().unwrap()
                ]
            );
            assert_eq!(
                &points[points.len() - 2..],
                &[
                    route["last"][0].as_f64().unwrap(),
                    route["last"][1].as_f64().unwrap()
                ]
            );
            assert_eq!(points, decode());
            let km = route["km"].as_f64().unwrap();
            assert!((fare_for(km).unwrap() - (2.5 + 1.5 * km * 0.621371)).abs() <= 0.06);
        }
    }

    #[test]
    fn fares_preserve_tenths_and_reject_non_finite() {
        for (km, fare) in [
            (0.0, 2.5),
            (1.0, 3.4),
            (1.472, 3.9),
            (6.833, 8.9),
            (15.698, 17.1),
        ] {
            assert_eq!(fare_for(km).unwrap(), fare);
        }
        for value in [f64::NAN, f64::INFINITY, f64::NEG_INFINITY, f64::MAX] {
            assert!(fare_for(value).is_err());
        }
        assert_eq!(fare_for(1e18).unwrap(), i64::MAX as f64 / 10.0);
    }
}
