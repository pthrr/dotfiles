use regex::Regex;
use std::fs;
use std::thread::sleep;
use std::time::Duration;

#[derive(Debug)]
struct CPUStat {
    user: u64,
    nice: u64,
    system: u64,
    idle: u64,
    iowait: u64,
    irq: u64,
    softirq: u64,
    steal: u64,
}

fn parse_cpu_stat(line: &str) -> Option<CPUStat> {
    let parts: Vec<&str> = line.split_whitespace().collect();
    let re = Regex::new(r"^cpu\d+$").unwrap();
    if parts.len() >= 9 && re.is_match(parts[0]) {
        Some(CPUStat {
            user: parts[1].parse().ok()?,
            nice: parts[2].parse().ok()?,
            system: parts[3].parse().ok()?,
            idle: parts[4].parse().ok()?,
            iowait: parts[5].parse().ok()?,
            irq: parts[6].parse().ok()?,
            softirq: parts[7].parse().ok()?,
            steal: parts[8].parse().ok()?,
        })
    } else {
        None
    }
}

fn cpu_usage_percentage(prev: &CPUStat, curr: &CPUStat) -> f64 {
    let prev_total = prev.user
        + prev.nice
        + prev.system
        + prev.idle
        + prev.iowait
        + prev.irq
        + prev.softirq
        + prev.steal;
    let curr_total = curr.user
        + curr.nice
        + curr.system
        + curr.idle
        + curr.iowait
        + curr.irq
        + curr.softirq
        + curr.steal;
    let total_diff = curr_total as f64 - prev_total as f64;
    let idle_diff =
        (curr.idle as f64 - prev.idle as f64) + (curr.iowait as f64 - prev.iowait as f64);
    100.0 * (1.0 - idle_diff / total_diff)
}

fn main() {
    let content = fs::read_to_string("/proc/stat").unwrap();
    let lines: Vec<&str> = content.lines().collect();
    let prev_stats: Vec<CPUStat> = lines
        .iter()
        .filter_map(|&line| parse_cpu_stat(line))
        .collect();

    sleep(Duration::from_secs(1));

    let content = fs::read_to_string("/proc/stat").unwrap();
    let lines: Vec<&str> = content.lines().collect();
    let curr_stats: Vec<CPUStat> = lines
        .iter()
        .filter_map(|&line| parse_cpu_stat(line))
        .collect();

    for (i, (prev, curr)) in prev_stats.iter().zip(curr_stats.iter()).enumerate() {
        println!("CPU{} Usage: {:.2}%", i, cpu_usage_percentage(prev, curr));
    }
}
