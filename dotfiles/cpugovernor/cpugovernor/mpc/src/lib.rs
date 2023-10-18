pub fn add(left: usize, right: usize) -> usize {
    left + right
}
fn mpc(
    kalman_state: f32,
    target: f32,
    horizon: usize,
    A: f32,
    B: f32,
    min_u: f32,
    max_u: f32,
) -> f32 {
    let mut best_u = 0.0;
    let mut best_cost = f32::MAX;

    // Discretization of control actions
    let control_step = 0.1; // Define granularity
    for u in (min_u..max_u).step_by(control_step) {
        let mut x = kalman_state;
        let mut cost = 0.0;
        let mut valid = true; // Flag to check if sequence respects state constraints

        for _ in 0..horizon {
            x = A * x + B * u;

            if x < MIN_STATE || x > MAX_STATE {
                valid = false;
                break;
            }

            cost += (x - target).powi(2);
        }

        if valid && cost < best_cost {
            best_cost = cost;
            best_u = u;
        }
    }
    best_u
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
