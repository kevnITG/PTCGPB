use ab_glyph::{Font as _, FontArc, PxScale, ScaleFont};
use anyhow::Context;
use clap::Parser;
use futures::future::join_all;
use image::{ImageBuffer, Rgba, RgbaImage};
use imageproc::drawing::{
    draw_filled_circle_mut, draw_hollow_circle_mut, draw_hollow_rect_mut, draw_text_mut,
};
use imageproc::rect::Rect;
use reqwest::Client;
use serde::Deserialize;
use std::collections::{HashMap, HashSet};
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::fs;

#[derive(Parser)]
#[command(name = "cardimage", about = "Generate a card pack image for Discord")]
struct Cli {
    input: PathBuf,
    output: PathBuf,
    #[arg(long, default_value_t = 6)]
    cols: usize,
    #[arg(long, default_value = "cardmap.json")]
    cardmaster: PathBuf,
    #[arg(long, default_value = "CardImageCache")]
    cache_dir: PathBuf,
    /// Comma-separated cardIds to highlight with a gold border (wishlist matches).
    #[arg(long, default_value = "")]
    highlight: String,
}

#[derive(Deserialize)]
struct CardMapEntry {
    #[serde(rename = "IllustrationID")]
    illustration_id: Option<String>,
    #[serde(rename = "ExpansionID")]
    expansion_id: Option<String>,
    #[serde(rename = "CollectionNumber")]
    collection_number: Option<u32>,
}

type CardMap = HashMap<String, CardMapEntry>;

const CARDMAP_URL: &str = "https://leanny.github.io/pocket_tcg_resources/data/cardmap.json";

async fn load_cardmaster(path: &Path) -> anyhow::Result<CardMap> {
    let data = match fs::read_to_string(path).await {
        Ok(data) => data,
        Err(err) if err.kind() == ErrorKind::NotFound => {
            println!("  {:?} not found; downloading cardmap.json…", path);

            let data = Client::new()
                .get(CARDMAP_URL)
                .send()
                .await
                .context("Could not download cardmap.json")?
                .error_for_status()
                .context("cardmap.json download returned an error status")?
                .text()
                .await
                .context("Could not read downloaded cardmap.json")?;

            // Validate before saving, so we do not cache a bad file.
            serde_json::from_str::<CardMap>(&data)
                .context("Downloaded cardmap.json was not valid JSON")?;

            if let Some(parent) = path.parent() {
                if !parent.as_os_str().is_empty() {
                    fs::create_dir_all(parent).await?;
                }
            }

            fs::write(path, &data)
                .await
                .with_context(|| format!("Could not save downloaded cardmap.json to {:?}", path))?;

            data
        }
        Err(err) => {
            return Err(err).with_context(|| format!("Could not read cardmap file at {:?}", path));
        }
    };

    serde_json::from_str(&data)
        .with_context(|| format!("Could not parse cardmap JSON at {:?}", path))
}

fn get_ill_id<'a>(card_id: &str, cm: &'a CardMap) -> Option<&'a str> {
    cm.get(card_id)?.illustration_id.as_deref()
}

fn card_sort_key(card_id: &str, cm: &CardMap) -> (String, u32) {
    if let Some(entry) = cm.get(card_id) {
        let exp = entry.expansion_id.clone().unwrap_or_default();
        let num = entry.collection_number.unwrap_or(u32::MAX);
        return (exp, num);
    }
    // Fallback: derive from card ID segments (PK_NN_XXXXXX_YY)
    let parts: Vec<&str> = card_id.split('_').collect();
    let num = if parts.len() >= 3 {
        parts[2].parse::<u32>().map(|n| n / 10).unwrap_or(u32::MAX)
    } else {
        u32::MAX
    };
    (String::new(), num)
}

async fn fetch_one(client: Arc<Client>, url: String, dest: PathBuf) -> bool {
    if dest.exists() {
        if let Ok(meta) = std::fs::metadata(&dest) {
            if meta.len() > 1000 {
                return true;
            }
        }
        let _ = std::fs::remove_file(&dest);
    }

    let resp = match client.get(&url).send().await {
        Ok(r) if r.status().is_success() => r,
        _ => return false,
    };
    let bytes = match resp.bytes().await {
        Ok(b) if b.len() > 1000 => b,
        _ => return false,
    };

    if let Some(parent) = dest.parent() {
        let _ = fs::create_dir_all(parent).await;
    }
    fs::write(&dest, &bytes).await.is_ok()
}

async fn download_all(tasks: Vec<(String, PathBuf)>, max_conn: usize) -> Vec<bool> {
    let client = Arc::new(
        Client::builder()
            .pool_max_idle_per_host(max_conn)
            .build()
            .expect("HTTP client"),
    );

    let mut results = Vec::with_capacity(tasks.len());
    for chunk in tasks.chunks(max_conn) {
        let futs: Vec<_> = chunk
            .iter()
            .map(|(url, dest)| fetch_one(Arc::clone(&client), url.clone(), dest.clone()))
            .collect();
        results.extend(join_all(futs).await);
    }
    results
}

const CARD_W: u32 = 200;
const CARD_H: u32 = 280;
const PADDING: u32 = 10;
const BASE_COLS: u32 = 6;

const BG: Rgba<u8> = Rgba([26, 26, 46, 255]);
const PH_FILL: Rgba<u8> = Rgba([37, 37, 69, 255]);
const PH_BORDER: Rgba<u8> = Rgba([74, 74, 158, 255]);
const TEXT_COLOR: Rgba<u8> = Rgba([170, 170, 170, 255]);
// Wishlist badge: red gradient circle (#E8254F) with a white heart, top-right.
// Inspired by .wishlist-heart-btn.on in card_database.html.
const WISHLIST_BADGE_BG: Rgba<u8> = Rgba([232, 37, 79, 255]);
const WISHLIST_BADGE_RIM: Rgba<u8> = Rgba([255, 200, 210, 255]);
const WISHLIST_HEART: Rgba<u8> = Rgba([255, 255, 255, 255]);
// Sizes calibrated against the 6-col card width (CARD_W). When fewer columns
// are requested the card is rendered larger, so we scale the badge by
// card_w / CARD_W to keep the same visual proportion as on 6 cols.
const WISHLIST_BADGE_RADIUS_BASE: f32 = 22.0;
const WISHLIST_HEART_RADIUS_BASE: f32 = 14.0;
const WISHLIST_BADGE_OFFSET_BASE: f32 = 26.0; // center offset from the nearer corner

fn make_placeholder(card_id: &str, font: &FontArc, card_w: u32, card_h: u32) -> RgbaImage {
    let mut img: RgbaImage = ImageBuffer::from_pixel(card_w, card_h, PH_FILL);

    // Border
    draw_hollow_rect_mut(&mut img, Rect::at(0, 0).of_size(card_w, card_h), PH_BORDER);
    draw_hollow_rect_mut(
        &mut img,
        Rect::at(1, 1).of_size(card_w.saturating_sub(2), card_h.saturating_sub(2)),
        PH_BORDER,
    );

    let label: String = card_id.chars().take(20).collect();
    let scale = PxScale::from(13.0);
    let scaled_font = font.as_scaled(scale);
    let line_h =
        (scaled_font.ascent() - scaled_font.descent() + scaled_font.line_gap()).ceil() as u32;

    // Measure width to centre
    let glyph_width = |s: &str| -> u32 {
        let mut width = 0.0;
        let mut previous = None;

        for ch in s.chars() {
            let glyph_id = font.glyph_id(ch);
            if let Some(previous) = previous {
                width += scaled_font.kern(previous, glyph_id);
            }
            width += scaled_font.h_advance(glyph_id);
            previous = Some(glyph_id);
        }

        width.ceil() as u32
    };

    // Two-line split at '_' boundary around midpoint
    let mid = label.len() / 2;
    let split = label[..mid].rfind('_').map(|i| i + 1).unwrap_or(mid);
    let line1 = &label[..split];
    let line2 = &label[split..];

    let total_h = line_h * 2 + 4;
    let y_start = (card_h.saturating_sub(total_h)) / 2;

    for (i, line) in [line1, line2].iter().enumerate() {
        let w = glyph_width(line).max(1);
        let x = ((card_w.saturating_sub(w)) / 2) as i32;
        let y = (y_start + i as u32 * (line_h + 4)) as i32;
        draw_text_mut(&mut img, TEXT_COLOR, x, y, scale, font, line);
    }

    img
}

// For multi-pack/gift with n>6, pick the layout that makes cards largest after
// Discord scales the square preview. Raw card pixels alone are misleading:
// 7 cards in 3 columns gives wider source cards than 4 columns, but also creates
// a much taller square canvas, so the displayed cards can end up smaller.
fn pick_dynamic_cols(total: u32) -> u32 {
    let base_w = PADDING + BASE_COLS * (CARD_W + PADDING);
    let max_side = base_w * 7 / 5;
    let mut best_cols = BASE_COLS.min(total).max(1);
    let mut best_score_num = 0;
    let mut best_score_den = 1;

    for c in 2..=total {
        let card_w = base_w.saturating_sub((c + 1) * PADDING) / c;
        if card_w == 0 {
            continue;
        }
        let card_h = card_w * CARD_H / CARD_W;
        let rows = total.div_ceil(c);
        let grid_h = (rows + 1) * PADDING + rows * card_h;
        let side = base_w.max(grid_h);
        if side > max_side {
            continue;
        }

        if (card_w as u64) * best_score_den > best_score_num * (side as u64) {
            best_cols = c;
            best_score_num = card_w as u64;
            best_score_den = side as u64;
        }
    }

    best_cols
}

fn composite(
    cards: &[(String, Option<RgbaImage>)],
    max_cols: usize,
    font: &FontArc,
    highlight: &HashSet<String>,
) -> RgbaImage {
    let total = cards.len();
    // Multi-pack/gift mode (cols=6) gets dynamic layout management:
    //   n<=6: use the normal-pack 3-col layout (same look as standard openings,
    //         keeps cards readable instead of a thin strip)
    //   n>6 : pick the column count that minimizes empty padding so cards grow as
    //         large as possible within a square canvas
    let max_cols = if max_cols == 6 {
        if total <= 6 {
            3
        } else {
            pick_dynamic_cols(total as u32) as usize
        }
    } else {
        max_cols.max(1)
    };
    let cols = max_cols as u32;
    let rows = total.div_ceil(max_cols) as u32;

    // Keep the old 6-column canvas width even when fewer columns are requested.
    let grid_w = PADDING + BASE_COLS * (CARD_W + PADDING);
    let card_w = (grid_w.saturating_sub((cols + 1) * PADDING)) / cols;
    let card_h = card_w * CARD_H / CARD_W;
    // Variable height (based on rows)
    let grid_h = PADDING + rows * (card_h + PADDING);

    // Force a square canvas for consistent Discord gallery previews. The grid
    // is centered inside; the shorter dimension is padded with BG.
    let side = grid_w.max(grid_h);
    let pad_x = (side - grid_w) / 2;
    let pad_y = (side - grid_h) / 2;

    let mut canvas: RgbaImage = ImageBuffer::from_pixel(side, side, BG);

    for (idx, (card_id, img_opt)) in cards.iter().enumerate() {
        let col = (idx % max_cols) as u32;
        let row = (idx / max_cols) as u32;

        // Calculate cards in this row for centering
        let cards_in_row = if row == rows - 1 {
            // Last row might be incomplete
            let remainder = total % max_cols;
            if remainder == 0 {
                max_cols
            } else {
                remainder
            }
        } else {
            // Full rows always have max_cols cards
            max_cols
        };

        // Center cards horizontally when row is not full
        let unused_slots = max_cols - cards_in_row;
        let center_offset = (unused_slots as u32 * (card_w + PADDING)) / 2;

        let x = pad_x + PADDING + center_offset + col * (card_w + PADDING);
        let y = pad_y + PADDING + row * (card_h + PADDING);

        let card_img: RgbaImage = match img_opt {
            Some(src) => {
                // Resize to fit slot
                let resized = image::imageops::resize(
                    src,
                    card_w,
                    card_h,
                    image::imageops::FilterType::Lanczos3,
                );
                resized
            }
            None => make_placeholder(card_id, font, card_w, card_h),
        };

        image::imageops::overlay(&mut canvas, &card_img, x as i64, y as i64);

        if highlight.contains(card_id) {
            let scale = card_w as f32 / CARD_W as f32;
            let badge_radius = (WISHLIST_BADGE_RADIUS_BASE * scale).round() as i32;
            let heart_radius = WISHLIST_HEART_RADIUS_BASE * scale;
            let badge_offset = (WISHLIST_BADGE_OFFSET_BASE * scale).round() as i32;
            let cx = x as i32 + card_w as i32 - badge_offset;
            let cy = y as i32 + badge_offset;
            draw_filled_circle_mut(&mut canvas, (cx, cy), badge_radius, WISHLIST_BADGE_BG);
            draw_hollow_circle_mut(&mut canvas, (cx, cy), badge_radius, WISHLIST_BADGE_RIM);
            draw_heart(&mut canvas, cx, cy, heart_radius, WISHLIST_HEART);
        }
    }

    canvas
}

// Fills pixels inside the implicit heart curve (x² + y² − 1)³ − x²·y³ ≤ 0,
// scaled to `radius`, centered at (cx, cy). Pixel-rasterised, no AA.
fn draw_heart(canvas: &mut RgbaImage, cx: i32, cy: i32, radius: f32, color: Rgba<u8>) {
    // The curve extends past |x|=1 (up to ~±1.13 at the widest lobe), the
    // lobes peak slightly above y=1, and the +0.25 vertical shift pushes the
    // bottom tip down to ~1.25r below center. Iterating only [-r, r] clips
    // the sides, the lobe tops, and the bottom point. Extra iterations are
    // free (the curve check filters them out).
    let r_x = (radius * 1.3).ceil() as i32;
    let r_y_top = (radius * 1.1).ceil() as i32;
    let r_y_bot = (radius * 1.4).ceil() as i32;
    let (w, h) = (canvas.width() as i32, canvas.height() as i32);
    for dy in -r_y_top..=r_y_bot {
        for dx in -r_x..=r_x {
            let x = dx as f32 / radius;
            // Flip vertically and shift up so the heart sits visually centered
            // (the curve's bounding box is taller above than below).
            let y = -(dy as f32) / radius + 0.25;
            let t = x * x + y * y - 1.0;
            if t * t * t - x * x * y * y * y <= 0.0 {
                let px = cx + dx;
                let py = cy + dy;
                if px >= 0 && py >= 0 && px < w && py < h {
                    canvas.put_pixel(px as u32, py as u32, color);
                }
            }
        }
    }
}

fn parse_ids(input: &str) -> Vec<String> {
    input
        .lines()
        .flat_map(|line| line.split(','))
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seven_cards_use_two_rows_for_larger_discord_preview() {
        assert_eq!(pick_dynamic_cols(7), 4);
    }

    #[test]
    fn nine_cards_still_prefer_three_large_columns() {
        assert_eq!(pick_dynamic_cols(9), 3);
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    let raw = std::fs::read_to_string(&cli.input)?;
    let card_ids = parse_ids(&raw);
    if card_ids.is_empty() {
        eprintln!("No card IDs found in {:?}", cli.input);
        std::process::exit(1);
    }

    let cardmaster = load_cardmaster(&cli.cardmaster).await?;
    // cardmaster here is actually cardmap.json (has ExpansionID + CollectionNumber + IllustrationID)
    fs::create_dir_all(&cli.cache_dir).await?;

    let base_url = "https://leanny.github.io/pocket_tcg_resources/img/S/US";

    let mut ill_ids: Vec<Option<String>> = Vec::with_capacity(card_ids.len());
    let mut cached_paths: Vec<Option<PathBuf>> = Vec::with_capacity(card_ids.len());
    let mut to_download: Vec<(String, PathBuf)> = Vec::new();

    for cid in &card_ids {
        let ill_id = get_ill_id(cid, &cardmaster).map(str::to_owned);
        if let Some(ref id) = ill_id {
            let safe: String = id
                .chars()
                .map(|c| if "\\/:<>\"*?|".contains(c) { '_' } else { c })
                .collect();
            let dest = cli.cache_dir.join(format!("{safe}.png"));
            let needs_dl =
                !dest.exists() || std::fs::metadata(&dest).map(|m| m.len()).unwrap_or(0) <= 1000;
            if needs_dl {
                let url = format!("{base_url}/{id}.png");
                to_download.push((url, dest.clone()));
            }
            cached_paths.push(Some(dest));
        } else {
            cached_paths.push(None);
        }
        ill_ids.push(ill_id);
    }

    let dl_results = download_all(to_download, 20).await;
    let failed = dl_results.iter().filter(|&&ok| !ok).count();
    if failed > 0 {
        eprintln!("{failed} image(s) failed to download (shown as placeholders)");
    }

    let mut cards: Vec<(String, Option<RgbaImage>)> = Vec::with_capacity(card_ids.len());
    for (cid, path_opt) in card_ids.iter().zip(cached_paths.iter()) {
        let img = path_opt.as_ref().and_then(|p| {
            if p.exists() && std::fs::metadata(p).map(|m| m.len()).unwrap_or(0) > 1000 {
                image::open(p).ok().map(|i| i.to_rgba8())
            } else {
                None
            }
        });
        cards.push((cid.clone(), img));
    }

    // Sort by ExpansionID (alphabetical: A1 < A1a < A2 ...) then CollectionNumber (numeric)
    cards.sort_by(|a, b| {
        let ka = card_sort_key(&a.0, &cardmaster);
        let kb = card_sort_key(&b.0, &cardmaster);
        ka.cmp(&kb)
    });

    let font_data = include_bytes!("font.ttf");
    let font = FontArc::try_from_slice(font_data as &[u8]).expect("embedded font");
    let highlight: HashSet<String> = cli
        .highlight
        .split(',')
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
        .collect();
    let result = composite(&cards, cli.cols, &font, &highlight);
    if let Some(parent) = cli.output.parent() {
        fs::create_dir_all(parent).await?;
    }
    result.save(&cli.output)?;

    Ok(())
}
