use anyhow::{Context, Result};
use chrono::{DateTime, Duration, Local, NaiveDateTime, TimeZone, Utc};
use clap::{Parser, Subcommand};
use serde_json::{json, Map, Value};
use std::cmp::Reverse;
use std::collections::{BTreeMap, HashMap, HashSet};
use std::env;
use std::fs::{self, OpenOptions};
use std::io::{ErrorKind, Write};
use std::path::{Path, PathBuf};
use std::process::Command as ProcessCommand;

#[derive(Parser)]
#[command(
    name = "carddb",
    about = "Merge staged card database and metadata files"
)]
struct Cli {
    #[arg(long, default_value = ".")]
    root: PathBuf,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    MergeCardDb,
    MergeMetadata,
    EnsureMetadata,
    ScheduleAccounts {
        #[arg(long)]
        instance: String,
        #[arg(long)]
        delete_method: String,
        #[arg(long)]
        sort_method: String,
        #[arg(long, default_value_t = 96, value_parser = clap::value_parser!(i64).range(70..=999))]
        inject_wonderpick_min_packs: i64,
        #[arg(long, default_value_t = false)]
        wonderpick_for_event_missions: bool,
        #[arg(long, default_value_t = false)]
        claim_special_missions: bool,
        #[arg(long, default_value_t = false)]
        receive_gift: bool,
        #[arg(long, default_value_t = false)]
        ocr_shinedust: bool,
        #[arg(long, default_value_t = false)]
        s4t_enabled: bool,
        #[arg(long, default_value_t = false)]
        spend_hourglass: bool,
        #[arg(long, default_value_t = false)]
        force_clear_used: bool,
    },
    BalanceXmls {
        #[arg(long)]
        instances: usize,
        #[arg(long)]
        delete_method: String,
        #[arg(long)]
        sort_method: String,
        #[arg(long, default_value_t = 96, value_parser = clap::value_parser!(i64).range(70..=999))]
        inject_wonderpick_min_packs: i64,
        #[arg(long, default_value_t = false)]
        wonderpick_for_event_missions: bool,
        #[arg(long, default_value_t = false)]
        claim_special_missions: bool,
        #[arg(long, default_value_t = false)]
        receive_gift: bool,
        #[arg(long, default_value_t = false)]
        ocr_shinedust: bool,
        #[arg(long, default_value_t = false)]
        s4t_enabled: bool,
        #[arg(long, default_value_t = false)]
        spend_hourglass: bool,
    },
    ExtractMetadata {
        #[arg(long)]
        device_account: Option<String>,
        #[arg(long)]
        instance: Option<String>,
        #[arg(long)]
        file_name: Option<String>,
        #[arg(long)]
        key: Option<String>,
        #[arg(long)]
        output: PathBuf,
    },
    ClearFlag {
        #[arg(long)]
        flag: String,
    },
    ImportHistory {
        #[arg(long)]
        device_account: String,
        #[arg(long)]
        input: PathBuf,
    },
    FormatAccount {
        #[arg(long)]
        device_account: String,
    },
    AppendPull {
        #[arg(long)]
        device_account: String,
        #[arg(long)]
        timestamp: String,
        #[arg(long)]
        pack: String,
        #[arg(long)]
        cards: String,
    },
    BuildDashboardCache {
        #[arg(long)]
        output: PathBuf,
        #[arg(long)]
        meta: PathBuf,
        #[arg(long)]
        signature: String,
        #[arg(long)]
        source_count: usize,
        #[arg(long)]
        source_bytes: u64,
    },
}

fn main() {
    let root_for_early_errors = root_arg_from_env().unwrap_or_else(|| PathBuf::from("."));
    std::panic::set_hook(Box::new({
        let root = root_for_early_errors.clone();
        move |panic_info| {
            let error_text = format!("carddb panic: {panic_info}\n");
            write_carddb_error(&root, &error_text);
            append_carddb_log(&root, &error_text);
        }
    }));

    let cli = match Cli::try_parse() {
        Ok(cli) => cli,
        Err(err) => {
            let error_text = format!("carddb argument parsing failed:\n{err}\n");
            write_carddb_error(&root_for_early_errors, &error_text);
            append_carddb_log(&root_for_early_errors, &error_text);
            err.exit();
        }
    };
    let root = cli.root.clone();
    let error_path = saved_dir(&root).join("carddb_error.txt");
    let _ = fs::remove_file(&error_path);
    append_carddb_log(&root, "carddb run started");
    if let Err(err) = run(cli) {
        let error_text = format!("{err:#}\n");
        write_carddb_error(&root, &error_text);
        append_carddb_log(&root, &format!("carddb run failed: {}", error_text.trim()));
        eprintln!("{error_text}");
        std::process::exit(1);
    }
    append_carddb_log(&root, "carddb run completed");
}

fn root_arg_from_env() -> Option<PathBuf> {
    let mut args = env::args_os().skip(1);
    while let Some(arg) = args.next() {
        if arg == "--root" {
            return args.next().map(PathBuf::from);
        }
    }
    None
}

fn write_carddb_error(root: &Path, error_text: &str) {
    let _ = fs::create_dir_all(saved_dir(root));
    let _ = fs::write(saved_dir(root).join("carddb_error.txt"), error_text);
}

fn append_carddb_log(root: &Path, message: &str) {
    let _ = fs::create_dir_all(saved_dir(root));
    let path = saved_dir(root).join("carddb_balance.log");
    let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S%.3f");
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
        let _ = writeln!(file, "[{timestamp}] {message}");
    }
}

fn run(cli: Cli) -> Result<()> {
    match cli.command {
        Command::MergeCardDb => merge_card_db(&cli.root),
        Command::MergeMetadata => merge_metadata(&cli.root),
        Command::EnsureMetadata => ensure_metadata(&cli.root).map(|_| ()),
        Command::ScheduleAccounts {
            instance,
            delete_method,
            sort_method,
            inject_wonderpick_min_packs,
            wonderpick_for_event_missions,
            claim_special_missions,
            receive_gift,
            ocr_shinedust,
            s4t_enabled,
            spend_hourglass,
            force_clear_used,
        } => schedule_accounts(
            &cli.root,
            ScheduleOptions {
                instance,
                delete_method,
                sort_method,
                inject_wonderpick_min_packs,
                wonderpick_for_event_missions,
                claim_special_missions,
                receive_gift,
                ocr_shinedust,
                s4t_enabled,
                spend_hourglass,
                force_clear_used,
            },
        ),
        Command::BalanceXmls {
            instances,
            delete_method,
            sort_method,
            inject_wonderpick_min_packs,
            wonderpick_for_event_missions,
            claim_special_missions,
            receive_gift,
            ocr_shinedust,
            s4t_enabled,
            spend_hourglass,
        } => balance_xmls(
            &cli.root,
            instances,
            ScheduleOptions {
                instance: String::new(),
                delete_method,
                sort_method,
                inject_wonderpick_min_packs,
                wonderpick_for_event_missions,
                claim_special_missions,
                receive_gift,
                ocr_shinedust,
                s4t_enabled,
                spend_hourglass,
                force_clear_used: false,
            },
        ),
        Command::ExtractMetadata {
            device_account,
            instance,
            file_name,
            key,
            output,
        } => extract_metadata(&cli.root, device_account, instance, file_name, key, &output),
        Command::ClearFlag { flag } => clear_flag(&cli.root, &flag),
        Command::ImportHistory {
            device_account,
            input,
        } => import_history(&cli.root, &device_account, &input),
        Command::FormatAccount { device_account } => format_account(&cli.root, &device_account),
        Command::AppendPull {
            device_account,
            timestamp,
            pack,
            cards,
        } => append_pull(&cli.root, &device_account, &timestamp, &pack, &cards),
        Command::BuildDashboardCache {
            output,
            meta,
            signature,
            source_count,
            source_bytes,
        } => build_dashboard_cache(
            &cli.root,
            &output,
            &meta,
            &signature,
            source_count,
            source_bytes,
        ),
    }
}

fn cards_dir(root: &Path) -> PathBuf {
    root.join("Accounts").join("Cards")
}

fn account_files_dir(root: &Path) -> PathBuf {
    cards_dir(root).join("accounts")
}

fn saved_dir(root: &Path) -> PathBuf {
    root.join("Accounts").join("Saved")
}

fn migration_progress_path(root: &Path) -> PathBuf {
    saved_dir(root).join("metadata_migration_progress.txt")
}

fn balance_progress_path(root: &Path) -> PathBuf {
    saved_dir(root).join("balance_progress.txt")
}

fn clear_flag_progress_path(root: &Path) -> PathBuf {
    saved_dir(root).join("clear_flag_progress.txt")
}

fn write_migration_progress(root: &Path, percent: u8, message: &str) -> Result<()> {
    fs::create_dir_all(saved_dir(root))?;
    fs::write(
        migration_progress_path(root),
        format!("{}|{}\n", percent.min(100), message),
    )?;
    Ok(())
}

fn write_balance_progress(root: &Path, percent: u8, message: &str) -> Result<()> {
    fs::create_dir_all(saved_dir(root))?;
    fs::write(
        balance_progress_path(root),
        format!("{}|{}\n", percent.min(100), message),
    )?;
    Ok(())
}

fn write_clear_flag_progress(root: &Path, percent: u8, message: &str) -> Result<()> {
    fs::create_dir_all(saved_dir(root))?;
    fs::write(
        clear_flag_progress_path(root),
        format!("{}|{}\n", percent.min(100), message),
    )?;
    Ok(())
}

fn safe_file_name(value: &str) -> String {
    value
        .chars()
        .map(|c| if "\\/:*?\"<>|".contains(c) { '_' } else { c })
        .collect()
}

fn account_file_path(root: &Path, account_key: &str) -> PathBuf {
    account_files_dir(root).join(format!("{}.json", safe_file_name(account_key)))
}

fn account_key_from_file(path: &Path) -> Option<String> {
    path.file_stem().map(|s| s.to_string_lossy().to_string())
}

fn build_dashboard_cache(
    root: &Path,
    output: &Path,
    meta: &Path,
    signature: &str,
    source_count: usize,
    source_bytes: u64,
) -> Result<()> {
    let dir = account_files_dir(root);
    let mut paths = Vec::new();
    if dir.exists() {
        for entry in fs::read_dir(&dir).with_context(|| format!("Could not read {:?}", dir))? {
            let path = entry?.path();
            if path
                .extension()
                .and_then(|e| e.to_str())
                .is_some_and(|e| e.eq_ignore_ascii_case("json"))
            {
                paths.push(path);
            }
        }
    }
    paths.sort_by(|a, b| {
        a.file_name()
            .map(|s| s.to_string_lossy())
            .cmp(&b.file_name().map(|s| s.to_string_lossy()))
    });

    let mut accounts = Vec::with_capacity(paths.len());
    let mut skipped = Vec::new();

    for path in paths {
        let file_name = path
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();
        match load_dashboard_account_document(&path, &file_name) {
            Ok(doc) => accounts.push(doc),
            Err(err) => skipped.push(json!({
                "file": file_name,
                "error": err.to_string(),
            })),
        }
    }

    let account_count = accounts.len();
    let skipped_count = skipped.len();
    let payload = json!({
        "ok": true,
        "source": "Accounts/Cards/accounts",
        "accountCount": account_count,
        "skippedCount": skipped_count,
        "skipped": skipped,
        "accounts": accounts,
    });
    let meta_payload = json!({
        "signature": signature,
        "sourceCount": source_count,
        "sourceBytes": source_bytes,
        "accountCount": account_count,
        "skippedCount": skipped_count,
        "generatedAt": Utc::now().to_rfc3339(),
        "generator": "carddb",
    });

    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent)?;
    }
    if let Some(parent) = meta.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(output, serde_json::to_vec(&payload)?)?;
    fs::write(meta, serde_json::to_vec(&meta_payload)?)?;
    Ok(())
}

fn load_dashboard_account_document(path: &Path, file_name: &str) -> Result<Value> {
    let text = fs::read_to_string(path).with_context(|| format!("Could not read {:?}", path))?;
    let mut value: Value = serde_json::from_str(text.trim_start_matches('\u{feff}'))
        .with_context(|| format!("Could not parse {:?}", path))?;
    if !value.is_object() {
        anyhow::bail!("Account JSON is not an object.");
    }

    let fallback_account = path
        .file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_default();
    let obj = value.as_object_mut().expect("dashboard account object");
    let device_account_blank = obj
        .get("deviceAccount")
        .and_then(Value::as_str)
        .map(str::trim)
        .unwrap_or("")
        .is_empty();
    if device_account_blank {
        obj.insert("deviceAccount".to_owned(), json!(fallback_account));
    }
    if obj.get("metadata").map_or(true, Value::is_null) {
        obj.insert("metadata".to_owned(), json!({}));
    }
    if obj.get("pulls").map_or(true, Value::is_null) {
        obj.insert("pulls".to_owned(), json!([]));
    }
    obj.insert("sourceFileName".to_owned(), json!(file_name));
    Ok(value)
}

fn merge_card_db(root: &Path) -> Result<()> {
    append_carddb_log(root, "merge_card_db entered");
    migrate_legacy_card_database(root)?;
    append_carddb_log(root, "merge_card_db completed");
    Ok(())
}

fn parse_csv_line(line: &str) -> Vec<String> {
    let mut fields = Vec::new();
    let mut field = String::new();
    let mut chars = line.chars().peekable();
    let mut in_quotes = false;

    while let Some(ch) = chars.next() {
        match ch {
            '"' if in_quotes && chars.peek() == Some(&'"') => {
                field.push('"');
                chars.next();
            }
            '"' => in_quotes = !in_quotes,
            ',' if !in_quotes => {
                fields.push(field);
                field = String::new();
            }
            _ => field.push(ch),
        }
    }
    fields.push(field);
    fields
}

fn pulls_from_fields(
    fields: &[String],
    cardmap: Option<&HashMap<String, String>>,
) -> Option<(String, Vec<Value>)> {
    if fields.len() < 4 {
        return None;
    }

    let timestamp = fields[0].trim().trim_start_matches('\u{feff}');
    if timestamp.eq_ignore_ascii_case("Timestamp") || timestamp.is_empty() {
        return None;
    }
    let timestamp = normalize_pull_timestamp(timestamp).unwrap_or_else(|| timestamp.to_owned());

    let device_account = fields[1].trim();
    if device_account.is_empty() {
        return None;
    }

    let cards: Vec<String> = fields[3]
        .split('|')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_owned)
        .collect();

    if cards.is_empty() {
        return None;
    }

    let has_multiple_packs = fields[2]
        .split(',')
        .filter(|s| !s.trim().is_empty())
        .count()
        > 1;
    if has_multiple_packs {
        let cardmap = cardmap?;
        let mut cards_by_pack: BTreeMap<String, Vec<Value>> = BTreeMap::new();
        for card in cards {
            let pack = cardmap
                .get(&card)
                .cloned()
                .unwrap_or_else(|| "unknown".to_owned());
            cards_by_pack.entry(pack).or_default().push(json!(card));
        }

        let pulls = cards_by_pack
            .into_iter()
            .map(|(pack, cards)| {
                json!({
                    "timestamp": timestamp,
                    "pack": pack,
                    "cards": cards,
                })
            })
            .collect();
        return Some((device_account.to_owned(), pulls));
    }

    let pull = json!({
        "timestamp": timestamp,
        "pack": fields[2].trim(),
        "cards": cards.into_iter().map(|card| json!(card)).collect::<Vec<_>>(),
    });
    Some((device_account.to_owned(), vec![pull]))
}

fn import_card_rows(root: &Path, csv_text: &str) -> Result<()> {
    let mut imported = 0usize;
    let mut cardmap = None;
    for line in csv_text.lines() {
        let line = line.trim_end_matches('\r');
        if line.trim().is_empty() {
            continue;
        }
        let fields = parse_csv_line(line);
        if fields
            .get(2)
            .is_some_and(|pack| pack.split(',').filter(|s| !s.trim().is_empty()).count() > 1)
            && cardmap.is_none()
        {
            append_carddb_log(
                root,
                "import_card_rows loading cardmap for multi-pack CSV rows",
            );
            cardmap = Some(load_cardmap(root)?);
        }

        if let Some((device_account, pulls)) = pulls_from_fields(&fields, cardmap.as_ref()) {
            for pull in pulls {
                append_pull_to_account_file(root, &device_account, pull)?;
                imported += 1;
            }
        }
    }
    append_carddb_log(
        root,
        &format!("import_card_rows completed; imported={imported}"),
    );
    Ok(())
}

fn migrate_legacy_card_database(root: &Path) -> Result<()> {
    let db_path = cards_dir(root).join("Card_Database.csv");
    if !db_path.exists() || fs::metadata(&db_path)?.len() == 0 {
        append_carddb_log(
            root,
            &format!(
                "migrate_legacy_card_database skipped; missing_or_empty={:?}",
                db_path
            ),
        );
        return Ok(());
    }

    let db_len = fs::metadata(&db_path)?.len();
    append_carddb_log(
        root,
        &format!(
            "migrate_legacy_card_database importing {:?}; bytes={db_len}",
            db_path
        ),
    );
    let content = fs::read_to_string(&db_path)
        .with_context(|| format!("Could not read legacy card database {:?}", db_path))?;
    import_card_rows(root, &content)?;

    let migrated = db_path.with_file_name(format!(
        "Card_Database.csv.migrated_{}",
        Local::now().format("%Y%m%d%H%M%S")
    ));
    fs::rename(&db_path, &migrated)
        .with_context(|| format!("Could not archive legacy card database to {:?}", migrated))?;
    append_carddb_log(
        root,
        &format!("migrate_legacy_card_database archived to {:?}", migrated),
    );
    Ok(())
}

fn load_store(path: &Path) -> Result<Value> {
    if !path.exists() || fs::metadata(path)?.len() == 0 {
        return Ok(json!({ "accounts": {} }));
    }

    let text = fs::read_to_string(path).with_context(|| format!("Could not read {:?}", path))?;
    let text = text.trim_start_matches('\u{feff}');
    let value: Value =
        serde_json::from_str(text).with_context(|| format!("Could not parse {:?}", path))?;
    Ok(ensure_store(value))
}

fn ensure_store(mut value: Value) -> Value {
    if !value.is_object() {
        value = json!({});
    }
    let obj = value.as_object_mut().expect("object");
    if !obj.get("accounts").is_some_and(Value::is_object) {
        obj.insert("accounts".to_owned(), json!({}));
    }
    normalize_store_keys(&mut value);
    value
}

fn normalize_store_keys(store: &mut Value) {
    let Some(accounts) = store.get_mut("accounts").and_then(Value::as_object_mut) else {
        return;
    };

    let old = std::mem::take(accounts);
    for (key, mut account) in old {
        let new_key = account_key(&key, &account);
        if let Some(obj) = account.as_object_mut() {
            obj.remove("deviceAccount");
        }
        if let Some(existing) = accounts.get_mut(&new_key) {
            merge_account(existing, &account);
        } else {
            accounts.insert(new_key, account);
        }
    }
}

fn compact_store_for_write(store: &Value) -> Value {
    let mut output = ensure_store(store.clone());
    let Some(accounts) = output.get_mut("accounts").and_then(Value::as_object_mut) else {
        return output;
    };

    for account in accounts.values_mut() {
        compact_account_for_write(account);
    }
    output
}

fn compact_account_for_write(account: &mut Value) {
    let Some(obj) = account.as_object_mut() else {
        return;
    };

    obj.remove("deviceAccount");
    normalize_legacy_last_modified(obj, "");

    let file_name = obj
        .get("fileName")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_owned();

    if obj
        .get("instance")
        .and_then(Value::as_str)
        .unwrap_or("")
        .is_empty()
    {
        obj.remove("instance");
    }
    if file_name.is_empty() {
        obj.remove("fileName");
    }

    if obj
        .get("packCount")
        .and_then(|value| {
            value
                .as_i64()
                .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
        })
        .is_some_and(|pack_count| pack_count == 0)
    {
        obj.remove("packCount");
    }

    if obj
        .get("createdAt")
        .and_then(Value::as_str)
        .is_some_and(|created_at| created_at.is_empty() || created_at == "0")
    {
        obj.remove("createdAt");
    }

    for key in ["lastPackPulled", "lastLoggedIn"] {
        if obj
            .get(key)
            .is_some_and(|value| value_is_zeroish(value) || value.as_str() == Some(""))
        {
            obj.remove(key);
        }
    }

    if obj
        .get("shinedust")
        .is_some_and(|value| !shinedust_is_meaningful(value))
    {
        obj.remove("shinedust");
    }

    if let Some(flags) = obj.get_mut("flags") {
        if let Some(flags_obj) = flags.as_object_mut() {
            flags_obj.retain(|_, flag| flag_is_meaningful(flag));
            for flag in flags_obj.values_mut() {
                compact_flag_for_write(flag);
            }
        }
        if flags.as_object().map_or(true, Map::is_empty) {
            obj.remove("flags");
        }
    }
}

fn value_truthy(value: &Value) -> bool {
    value.as_bool().unwrap_or(false) || value.as_i64().unwrap_or(0) != 0
}

fn add_days_stamp(timestamp: &str, days: i64) -> String {
    parse_local(timestamp)
        .map(|dt| {
            (dt + Duration::days(days))
                .format("%Y%m%d%H%M%S")
                .to_string()
        })
        .unwrap_or_default()
}

fn normalize_legacy_last_modified(obj: &mut Map<String, Value>, fallback_modified: &str) {
    let legacy_modified = obj
        .remove("lastModified")
        .and_then(|value| value.as_str().map(str::to_owned))
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| fallback_modified.to_owned());

    if legacy_modified.is_empty() {
        return;
    }

    if obj
        .get("lastPackPulled")
        .is_none_or(|value| value_is_zeroish(value) || value.as_str() == Some(""))
    {
        obj.insert("lastPackPulled".to_owned(), json!(legacy_modified.clone()));
    }

    let Some(t_flag) = obj
        .get_mut("flags")
        .and_then(Value::as_object_mut)
        .and_then(|flags| flags.get_mut("T"))
        .and_then(Value::as_object_mut)
    else {
        return;
    };

    if t_flag.get("value").is_some_and(value_truthy) {
        let valid_until = add_days_stamp(&legacy_modified, 5);
        if !valid_until.is_empty() {
            t_flag.insert("validUntil".to_owned(), json!(valid_until));
        }
    }
}

fn compact_flag_for_write(flag: &mut Value) {
    let Some(obj) = flag.as_object_mut() else {
        return;
    };
    if obj
        .get("value")
        .is_some_and(|value| !value.as_bool().unwrap_or(false) && value.as_i64().unwrap_or(0) == 0)
    {
        obj.remove("value");
    }
    if obj.get("setAt").and_then(Value::as_str) == Some("") {
        obj.remove("setAt");
    }
    if obj.get("validUntil").and_then(Value::as_str) == Some("") {
        obj.remove("validUntil");
    }
}

fn write_store(path: &Path, store: &Value) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    let tmp = path.with_extension("json.tmp");
    let output = compact_store_for_write(store);
    let data = serde_json::to_string_pretty(&output)?;
    fs::write(&tmp, data + "\n")?;
    fs::rename(&tmp, path)?;
    Ok(())
}

fn load_account_file(path: &Path, fallback_key: &str) -> Result<(String, Value)> {
    let text = fs::read_to_string(path).with_context(|| format!("Could not read {:?}", path))?;
    let value: Value = serde_json::from_str(text.trim_start_matches('\u{feff}'))
        .with_context(|| format!("Could not parse {:?}", path))?;
    let key = value
        .get("deviceAccount")
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .unwrap_or(fallback_key)
        .to_owned();
    let metadata = value.get("metadata").cloned().unwrap_or_else(|| json!({}));
    Ok((key, metadata))
}

fn load_account_files_store(root: &Path) -> Result<Value> {
    let dir = account_files_dir(root);
    let mut store = json!({ "accounts": {} });
    if !dir.exists() {
        return Ok(store);
    }

    let accounts = store["accounts"].as_object_mut().expect("accounts object");
    for entry in fs::read_dir(&dir).with_context(|| format!("Could not read {:?}", dir))? {
        let path = entry?.path();
        if !path
            .extension()
            .and_then(|e| e.to_str())
            .is_some_and(|e| e.eq_ignore_ascii_case("json"))
        {
            continue;
        }
        let fallback = account_key_from_file(&path).unwrap_or_default();
        let (key, metadata) = load_account_file(&path, &fallback)?;
        accounts.insert(key, metadata);
    }
    Ok(ensure_store(store))
}

fn account_files_exist(root: &Path) -> bool {
    let dir = account_files_dir(root);
    if !dir.exists() {
        return false;
    }
    fs::read_dir(dir)
        .ok()
        .into_iter()
        .flatten()
        .filter_map(Result::ok)
        .any(|entry| {
            entry
                .path()
                .extension()
                .and_then(|e| e.to_str())
                .is_some_and(|e| e.eq_ignore_ascii_case("json"))
        })
}

fn load_account_document(path: &Path, device_account: &str) -> Result<Value> {
    if path.exists() {
        let text = fs::read_to_string(path)?;
        let mut value: Value = serde_json::from_str(text.trim_start_matches('\u{feff}'))
            .with_context(|| format!("Could not parse {:?}", path))?;
        if !value.is_object() {
            value = json!({});
        }
        let obj = value.as_object_mut().expect("object");
        obj.entry("deviceAccount".to_owned())
            .or_insert_with(|| json!(device_account));
        obj.entry("metadata".to_owned())
            .or_insert_with(|| json!({}));
        obj.entry("pulls".to_owned()).or_insert_with(|| json!([]));
        return Ok(value);
    }

    Ok(json!({
        "deviceAccount": device_account,
        "metadata": {},
        "pulls": []
    }))
}

fn write_account_document(root: &Path, device_account: &str, doc: &Value) -> Result<()> {
    let path = account_file_path(root, device_account);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, serde_json::to_string_pretty(doc)? + "\n")?;
    fs::rename(tmp, path)?;
    Ok(())
}

fn format_account(root: &Path, device_account: &str) -> Result<()> {
    if device_account.trim().is_empty() {
        return Ok(());
    }

    let path = account_file_path(root, device_account);
    if !path.exists() {
        return Ok(());
    }

    let mut doc = load_account_document(&path, device_account)?;
    if let Some(metadata) = doc.get_mut("metadata") {
        compact_account_for_write(metadata);
    }
    write_account_document(root, device_account, &doc)
}

fn write_account_metadata(root: &Path, device_account: &str, metadata: &Value) -> Result<()> {
    let path = account_file_path(root, device_account);
    let mut doc = load_account_document(&path, device_account)?;
    doc["metadata"] = {
        let mut metadata = metadata.clone();
        compact_account_for_write(&mut metadata);
        metadata
    };
    write_account_document(root, device_account, &doc)
}

fn append_pull_to_account_file(root: &Path, device_account: &str, pull: Value) -> Result<()> {
    let path = account_file_path(root, device_account);
    let mut doc = load_account_document(&path, device_account)?;
    if !doc["pulls"].is_array() {
        doc["pulls"] = json!([]);
    }
    doc["pulls"].as_array_mut().expect("pulls array").push(pull);
    write_account_document(root, device_account, &doc)
}

fn write_account_files_from_store(root: &Path, store: &Value) -> Result<()> {
    let Some(accounts) = store.get("accounts").and_then(Value::as_object) else {
        return Ok(());
    };

    for (key, metadata) in accounts {
        if key.starts_with("legacy:") {
            continue;
        }
        write_account_metadata(root, key, metadata)?;
    }
    Ok(())
}

fn ymdhms_from_system_time(time: std::time::SystemTime) -> String {
    let dt: DateTime<Local> = time.into();
    dt.format("%Y%m%d%H%M%S").to_string()
}

fn modified_stamp(path: &Path) -> String {
    fs::metadata(path)
        .and_then(|m| m.modified())
        .map(ymdhms_from_system_time)
        .unwrap_or_default()
}

fn extract_pack_count(file_name: &str) -> i64 {
    initial_pack_count_from_filename(file_name)
}

fn extract_created_at(file_name: &str) -> String {
    initial_created_at_from_filename(file_name)
}

fn initial_pack_count_from_filename(file_name: &str) -> i64 {
    let mut digits = String::new();
    for ch in file_name.chars() {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else if ch == 'P' && !digits.is_empty() {
            return digits.parse().unwrap_or(0);
        } else {
            break;
        }
    }
    0
}

fn initial_created_at_from_filename(file_name: &str) -> String {
    if let Some(rest) = file_name.split_once("P_").map(|(_, rest)| rest) {
        let candidate: String = rest.chars().take(14).collect();
        if candidate.len() == 14 && candidate.chars().all(|c| c.is_ascii_digit()) {
            return candidate;
        }
    }

    "0".to_owned()
}

fn filename_flags(file_name: &str) -> HashSet<char> {
    let mut result = HashSet::new();
    let Some(open) = file_name.rfind('(') else {
        return result;
    };
    let Some(close_rel) = file_name[open + 1..].find(')') else {
        return result;
    };
    let flags = &file_name[open + 1..open + 1 + close_rel];
    for ch in flags.chars() {
        if matches!(ch, 'B' | 'X' | 'T' | 'R' | 'W' | 'H') {
            result.insert(ch);
        }
    }
    result
}

fn extract_device_account_from_xml(path: &Path) -> String {
    let Ok(text) = fs::read_to_string(path) else {
        return String::new();
    };
    let Some(start) = text.find(r#"<string name="deviceAccount">"#) else {
        return String::new();
    };
    let value_start = start + r#"<string name="deviceAccount">"#.len();
    let Some(value_end) = text[value_start..].find("</string>") else {
        return String::new();
    };
    text[value_start..value_start + value_end].to_owned()
}

fn new_flag(value: i64, set_at: &str, valid_until: &str) -> Value {
    json!({ "value": value, "setAt": set_at, "validUntil": valid_until })
}

fn new_account(instance: &str, file_name: &str, file_path: &Path) -> Value {
    let found_flags = filename_flags(file_name);
    let now = Local::now().format("%Y%m%d%H%M%S").to_string();
    let modified = modified_stamp(file_path);
    let flag_value = |name: char| {
        if found_flags.contains(&name) {
            let valid_until = if name == 'T' {
                add_days_stamp(&modified, 5)
            } else {
                String::new()
            };
            new_flag(1, &now, &valid_until)
        } else {
            new_flag(0, "", "")
        }
    };

    json!({
        "instance": instance,
        "fileName": file_name,
        "packCount": initial_pack_count_from_filename(file_name),
        "createdAt": initial_created_at_from_filename(file_name),
        "lastPackPulled": modified,
        "lastLoggedIn": "0",
        "shinedust": { "value": -1, "lastUpdatedAt": "0" },
        "flags": {
            "B": flag_value('B'),
            "X": flag_value('X'),
            "T": flag_value('T'),
            "R": flag_value('R'),
            "W": flag_value('W'),
            "H": flag_value('H'),
            "SH": new_flag(0, "", "")
        }
    })
}

fn walk_xml_files(dir: &Path, out: &mut Vec<PathBuf>) -> Result<()> {
    if !dir.exists() {
        return Ok(());
    }

    for entry in fs::read_dir(dir).with_context(|| format!("Could not read {:?}", dir))? {
        let path = entry?.path();
        if path.is_dir() {
            walk_xml_files(&path, out)?;
        } else if path
            .extension()
            .and_then(|ext| ext.to_str())
            .is_some_and(|ext| ext.eq_ignore_ascii_case("xml"))
        {
            out.push(path);
        }
    }
    Ok(())
}

fn legacy_metadata_path(root: &Path) -> PathBuf {
    cards_dir(root).join("metadata.json")
}

fn archive_legacy_metadata(path: &Path) -> Result<()> {
    if !path.exists() {
        return Ok(());
    }

    let migrated = path.with_file_name(format!(
        "metadata.json.migrated_{}",
        Local::now().format("%Y%m%d%H%M%S")
    ));
    fs::rename(path, migrated)?;
    Ok(())
}

fn scan_saved_xmls_into_store(root: &Path, store: &mut Value) -> Result<()> {
    let accounts = store["accounts"].as_object_mut().expect("accounts object");

    let mut xmls = Vec::new();
    walk_xml_files(&saved_dir(root), &mut xmls)?;

    for path in xmls {
        let Some(file_name_os) = path.file_name() else {
            continue;
        };
        let file_name = file_name_os.to_string_lossy().to_string();
        let instance = path
            .parent()
            .and_then(Path::file_name)
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();
        if instance.eq_ignore_ascii_case("tmp") {
            continue;
        }

        let device_account = extract_device_account_from_xml(&path);
        let key = if device_account.is_empty() {
            format!("legacy:{instance}/{file_name}")
        } else {
            device_account.clone()
        };

        let patch = new_account(&instance, &file_name, &path);
        let account_existed = accounts.contains_key(&key);
        let base = accounts.entry(key).or_insert_with(|| json!({}));
        let existing_pack_count = base
            .get("packCount")
            .and_then(|value| {
                value
                    .as_i64()
                    .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
            })
            .filter(|pack_count| *pack_count > 0);
        let existing_created_at = base.get("createdAt").cloned();
        let existing_last_pack_pulled = base
            .get("lastPackPulled")
            .filter(|value| !value_is_zeroish(value))
            .cloned();
        merge_account(base, &patch);
        if let Some(obj) = base.as_object_mut() {
            if account_existed {
                if let Some(pack_count) = existing_pack_count {
                    obj.insert("packCount".to_owned(), json!(pack_count));
                } else {
                    obj.insert(
                        "packCount".to_owned(),
                        json!(initial_pack_count_from_filename(&file_name)),
                    );
                }
                if let Some(created_at) = existing_created_at {
                    obj.insert("createdAt".to_owned(), created_at);
                } else {
                    obj.insert(
                        "createdAt".to_owned(),
                        json!(initial_created_at_from_filename(&file_name)),
                    );
                }
                if let Some(last_pack_pulled) = existing_last_pack_pulled {
                    obj.insert("lastPackPulled".to_owned(), last_pack_pulled);
                }
            }
            obj.insert("instance".to_owned(), json!(instance));
            obj.insert("fileName".to_owned(), json!(file_name));
            obj.remove("deviceAccount");
        }
    }

    Ok(())
}

fn ensure_metadata(root: &Path) -> Result<Value> {
    let had_account_files = account_files_exist(root);
    let metadata_path = legacy_metadata_path(root);
    let legacy_metadata_exists = metadata_path.exists() && fs::metadata(&metadata_path)?.len() > 0;
    let legacy_card_db_path = cards_dir(root).join("Card_Database.csv");
    let legacy_card_db_exists =
        legacy_card_db_path.exists() && fs::metadata(&legacy_card_db_path)?.len() > 0;
    let show_progress = !had_account_files || legacy_metadata_exists || legacy_card_db_exists;

    if show_progress {
        write_migration_progress(root, 1, "Preparing account data migration")?;
    }

    if show_progress && legacy_card_db_exists {
        write_migration_progress(root, 15, "Importing legacy card database")?;
    }
    merge_card_db(root)?;

    if account_files_exist(root) {
        let mut store = load_account_files_store(root)?;
        if metadata_path.exists() {
            if !had_account_files && fs::metadata(&metadata_path)?.len() > 0 {
                if show_progress {
                    write_migration_progress(root, 45, "Importing legacy metadata")?;
                }
                let legacy_store = load_store(&metadata_path)?;
                merge_store(&mut store, &legacy_store);
                if show_progress {
                    write_migration_progress(root, 70, "Writing account files")?;
                }
                write_account_files_from_store(root, &store)?;
            }
            if show_progress {
                write_migration_progress(root, 90, "Archiving legacy metadata")?;
            }
            archive_legacy_metadata(&metadata_path)?;
        }
        if show_progress {
            write_migration_progress(root, 100, "Account data migration complete")?;
        }
        return Ok(store);
    }

    let mut store = if metadata_path.exists() && fs::metadata(&metadata_path)?.len() > 0 {
        if show_progress {
            write_migration_progress(root, 35, "Reading legacy metadata")?;
        }
        load_store(&metadata_path)?
    } else {
        json!({ "accounts": {} })
    };

    if show_progress {
        write_migration_progress(root, 55, "Scanning saved XML files")?;
    }
    scan_saved_xmls_into_store(root, &mut store)?;
    if show_progress {
        write_migration_progress(root, 80, "Writing account files")?;
    }
    write_account_files_from_store(root, &store)?;
    if show_progress {
        write_migration_progress(root, 95, "Archiving legacy metadata")?;
    }
    archive_legacy_metadata(&metadata_path)?;
    if show_progress {
        write_migration_progress(root, 100, "Account data migration complete")?;
    }
    Ok(store)
}

fn merge_store(store: &mut Value, patch: &Value) {
    let Some(base_accounts) = store.get_mut("accounts").and_then(Value::as_object_mut) else {
        return;
    };
    let Some(patch_accounts) = patch.get("accounts").and_then(Value::as_object) else {
        return;
    };

    for (key, patch_account) in patch_accounts {
        let target_key = account_key(key, patch_account);
        let base_account = base_accounts.entry(target_key).or_insert_with(|| json!({}));
        merge_account(base_account, patch_account);
    }
}

fn account_key(input_key: &str, account: &Value) -> String {
    if let Some(device_account) = account
        .get("deviceAccount")
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
    {
        return device_account.to_owned();
    }

    input_key
        .strip_prefix("deviceAccount:")
        .unwrap_or(input_key)
        .to_owned()
}

fn meaningful(value: &Value) -> bool {
    match value {
        Value::Null => false,
        Value::String(s) => !s.is_empty(),
        Value::Number(_) | Value::Bool(_) => true,
        Value::Array(a) => !a.is_empty(),
        Value::Object(o) => !o.is_empty(),
    }
}

fn merge_account(base: &mut Value, patch: &Value) {
    if !base.is_object() {
        *base = json!({});
    }

    let Some(base_obj) = base.as_object_mut() else {
        return;
    };
    let Some(patch_obj) = patch.as_object() else {
        return;
    };
    let legacy_modified = patch_obj
        .get("lastModified")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_owned();

    for (key, value) in patch_obj {
        match key.as_str() {
            "flags" => merge_flags(base_obj, value),
            "shinedust" => {
                if shinedust_is_meaningful(value) {
                    base_obj.insert(key.clone(), value.clone());
                }
            }
            "lastPackPulled" | "lastLoggedIn" => {
                if !value_is_zeroish(value) {
                    base_obj.insert(key.clone(), value.clone());
                }
            }
            "lastModified" => {
                if !value_is_zeroish(value)
                    && base_obj
                        .get("lastPackPulled")
                        .is_none_or(|value| value_is_zeroish(value))
                {
                    base_obj.insert("lastPackPulled".to_owned(), value.clone());
                }
            }
            "packCount" => {
                if !value_is_zeroish(value) {
                    base_obj.insert(key.clone(), value.clone());
                }
            }
            "createdAt" => {
                if !value_is_zeroish(value) {
                    base_obj.insert(key.clone(), value.clone());
                }
            }
            _ => {
                if meaningful(value) {
                    base_obj.insert(key.clone(), value.clone());
                }
            }
        }
    }
    normalize_legacy_last_modified(base_obj, &legacy_modified);
}

fn merge_flags(base_obj: &mut Map<String, Value>, patch_flags: &Value) {
    let Some(patch_flags) = patch_flags.as_object() else {
        return;
    };

    let flags = base_obj.entry("flags").or_insert_with(|| json!({}));
    if !flags.is_object() {
        *flags = json!({});
    }
    let flags_obj = flags.as_object_mut().expect("flags object");

    for (flag, patch_flag) in patch_flags {
        if flag_is_meaningful(patch_flag) {
            flags_obj.insert(flag.clone(), patch_flag.clone());
        } else {
            flags_obj
                .entry(flag.clone())
                .or_insert_with(|| json!({ "value": 0, "setAt": "", "validUntil": "" }));
        }
    }
}

fn value_is_zeroish(value: &Value) -> bool {
    match value {
        Value::String(s) => s.is_empty() || s == "0",
        Value::Number(n) => n.as_i64() == Some(0),
        _ => false,
    }
}

fn shinedust_is_meaningful(value: &Value) -> bool {
    let Some(obj) = value.as_object() else {
        return meaningful(value);
    };

    let current = obj.get("value").and_then(Value::as_i64).unwrap_or(-1);
    let updated = obj
        .get("lastUpdatedAt")
        .and_then(Value::as_str)
        .unwrap_or("0");
    current != -1 || updated != "0"
}

fn flag_is_meaningful(value: &Value) -> bool {
    let Some(obj) = value.as_object() else {
        return meaningful(value);
    };

    obj.get("value").and_then(Value::as_i64).unwrap_or(0) != 0
        || obj.get("value").and_then(Value::as_bool).unwrap_or(false)
        || obj.get("setAt").and_then(Value::as_str).unwrap_or("") != ""
        || obj.get("validUntil").and_then(Value::as_str).unwrap_or("") != ""
}

fn merge_metadata(root: &Path) -> Result<()> {
    let store = ensure_metadata(root)?;
    write_account_files_from_store(root, &store)
}

struct ScheduleOptions {
    instance: String,
    delete_method: String,
    sort_method: String,
    inject_wonderpick_min_packs: i64,
    wonderpick_for_event_missions: bool,
    claim_special_missions: bool,
    receive_gift: bool,
    ocr_shinedust: bool,
    s4t_enabled: bool,
    spend_hourglass: bool,
    force_clear_used: bool,
}

struct Candidate {
    file_name: String,
    sort_time: String,
    last_login: String,
    pack_count: i64,
}

struct UsedAccountsState {
    used: HashSet<String>,
    backup: Option<PathBuf>,
}

struct AccountLookup {
    by_file: HashMap<String, Value>,
    by_device: HashMap<String, Value>,
}

fn parse_local(timestamp: &str) -> Option<DateTime<Local>> {
    if timestamp.is_empty() || timestamp == "0" {
        return None;
    }
    NaiveDateTime::parse_from_str(timestamp, "%Y%m%d%H%M%S")
        .ok()
        .and_then(|dt| Local.from_local_datetime(&dt).single())
}

fn hours_since(timestamp: &str) -> i64 {
    parse_local(timestamp)
        .map(|dt| (Local::now() - dt).num_hours())
        .unwrap_or(999_999)
}

fn timestamp_to_utc(timestamp: &str) -> Option<DateTime<Utc>> {
    parse_local(timestamp).map(|dt| dt.with_timezone(&Utc))
}

fn current_daily_reset_utc() -> DateTime<Utc> {
    let now = Utc::now();
    let today = now.date_naive();
    let reset_naive = today.and_hms_opt(6, 0, 0).expect("valid reset time");
    let mut reset = Utc.from_utc_datetime(&reset_naive);
    if now < reset {
        reset -= Duration::days(1);
    }
    reset
}

fn was_after_daily_reset(timestamp: &str) -> bool {
    timestamp_to_utc(timestamp)
        .map(|dt| dt >= current_daily_reset_utc())
        .unwrap_or(false)
}

fn field_str<'a>(account: &'a Value, field: &str) -> &'a str {
    account.get(field).and_then(Value::as_str).unwrap_or("")
}

fn field_i64(account: &Value, field: &str) -> Option<i64> {
    account.get(field).and_then(|value| {
        value
            .as_i64()
            .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
    })
}

fn explicit_pack_count(account: &Value) -> Option<i64> {
    field_i64(account, "packCount").filter(|count| *count > 0)
}

fn flag<'a>(account: &'a Value, name: &str) -> Option<&'a Value> {
    account.get("flags")?.get(name)
}

fn flag_value(account: &Value, name: &str) -> bool {
    flag(account, name)
        .and_then(|flag| flag.get("value"))
        .map(|value| value.as_bool().unwrap_or(false) || value.as_i64().unwrap_or(0) != 0)
        .unwrap_or(false)
}

fn flag_set_at<'a>(account: &'a Value, name: &str) -> &'a str {
    flag(account, name)
        .and_then(|flag| flag.get("setAt"))
        .and_then(Value::as_str)
        .unwrap_or("")
}

fn flag_valid_until<'a>(account: &'a Value, name: &str) -> &'a str {
    flag(account, name)
        .and_then(|flag| flag.get("validUntil"))
        .and_then(Value::as_str)
        .unwrap_or("")
}

fn flag_is_expired(account: &Value, name: &str, hours_valid: i64) -> bool {
    if !flag_value(account, name) {
        return true;
    }

    let valid_until = flag_valid_until(account, name);
    if !valid_until.is_empty() {
        return Local::now().format("%Y%m%d%H%M%S").to_string().as_str() >= valid_until;
    }

    let set_at = flag_set_at(account, name);
    if set_at.is_empty() {
        return false;
    }

    hours_since(set_at) >= hours_valid
}

fn t_flag_blocks(account: &Value) -> bool {
    flag_value(account, "T") && !flag_is_expired(account, "T", 5 * 24)
}

fn shinedust_updated_at(account: &Value) -> &str {
    account
        .get("shinedust")
        .and_then(|s| s.get("lastUpdatedAt"))
        .and_then(Value::as_str)
        .unwrap_or("0")
}

fn inject_rewards_eligible(account: &Value, options: &ScheduleOptions) -> bool {
    let do_shinedust = options.ocr_shinedust && options.s4t_enabled;

    if !options.wonderpick_for_event_missions
        && !options.claim_special_missions
        && !options.receive_gift
        && !do_shinedust
    {
        return !was_after_daily_reset(field_str(account, "lastLoggedIn"));
    }

    (options.wonderpick_for_event_missions && flag_is_expired(account, "W", 24))
        || (options.claim_special_missions && !flag_value(account, "X"))
        || (options.receive_gift && !flag_value(account, "R"))
        || (do_shinedust && hours_since(shinedust_updated_at(account)) >= 24)
}

fn inject_pack_eligible(account: &Value, options: &ScheduleOptions) -> bool {
    if matches!(
        options.delete_method.as_str(),
        "Inject 13P+" | "Inject Wonderpick 96P+"
    ) && t_flag_blocks(account)
    {
        return false;
    }

    if options.delete_method == "Inject 13P+" && options.spend_hourglass {
        return flag_is_expired(account, "SH", 24);
    }

    let last_pack = field_str(account, "lastPackPulled");
    if last_pack == "0" || last_pack.is_empty() {
        return true;
    }

    hours_since(last_pack) >= 24
}

fn eligible(account: &Value, options: &ScheduleOptions) -> bool {
    match options.delete_method.as_str() {
        "Create Bots (13P)" => true,
        "Inject Rewards" => inject_rewards_eligible(account, options),
        "Inject 13P+" | "Inject Wonderpick 96P+" => inject_pack_eligible(account, options),
        _ => true,
    }
}

fn pack_range(method: &str) -> (i64, i64) {
    match method {
        "Inject Missions" => (0, 38),
        _ => (0, 9999),
    }
}

fn pack_count_allowed(
    method: &str,
    metadata_account: Option<&Value>,
    resolved_pack_count: i64,
    inject_wonderpick_min_packs: i64,
) -> bool {
    if method == "Inject Wonderpick 96P+" {
        return metadata_account
            .and_then(explicit_pack_count)
            .map_or(true, |pack_count| pack_count >= inject_wonderpick_min_packs);
    }

    let (min_packs, max_packs) = pack_range(method);
    resolved_pack_count >= min_packs && resolved_pack_count <= max_packs
}

fn cleanup_used_account_backups(save_dir: &Path, keep: Option<&Path>) -> Result<()> {
    if !save_dir.exists() {
        return Ok(());
    }

    for entry in fs::read_dir(save_dir).with_context(|| format!("Could not read {:?}", save_dir))? {
        let path = entry?.path();
        let is_used_backup = path
            .file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| {
                name.starts_with("used_accounts_backup_") && name.ends_with(".txt")
            });
        if !is_used_backup {
            continue;
        }
        if keep.is_some_and(|keep| keep == path) {
            continue;
        }
        let _ = fs::remove_file(path);
    }

    Ok(())
}

fn clean_used_accounts(save_dir: &Path, force_clear: bool) -> Result<UsedAccountsState> {
    let used_path = save_dir.join("used_accounts.txt");
    if force_clear {
        let mut backup = None;
        if used_path.exists() {
            let backup_path = save_dir.join(format!(
                "used_accounts_backup_{}.txt",
                Local::now().format("%Y%m%d%H%M%S")
            ));
            fs::copy(&used_path, &backup_path)?;
            fs::remove_file(&used_path)?;
            backup = Some(backup_path);
        }
        cleanup_used_account_backups(save_dir, backup.as_deref())?;
        return Ok(UsedAccountsState {
            used: HashSet::new(),
            backup,
        });
    }

    cleanup_used_account_backups(save_dir, None)?;
    let mut used = HashSet::new();
    if !used_path.exists() {
        return Ok(UsedAccountsState { used, backup: None });
    }

    let text = fs::read_to_string(&used_path)?;
    let cutoff = Local::now() - Duration::hours(24);
    let mut kept_lines = Vec::new();

    for line in text.lines() {
        let mut parts = line.split('|');
        let Some(file_name) = parts.next() else {
            continue;
        };
        let timestamp = parts.next().unwrap_or("");
        if !save_dir.join(file_name).exists() {
            continue;
        }
        if parse_local(timestamp)
            .map(|dt| dt > cutoff)
            .unwrap_or(false)
        {
            used.insert(file_name.to_owned());
            kept_lines.push(line.to_owned());
        }
    }

    fs::write(
        &used_path,
        kept_lines
            .into_iter()
            .map(|line| line + "\n")
            .collect::<String>(),
    )?;

    Ok(UsedAccountsState { used, backup: None })
}

fn remove_used_accounts_backup(state: UsedAccountsState) {
    if let Some(backup) = state.backup {
        let _ = fs::remove_file(backup);
    }
}

fn accounts_for_instance(store: &Value, instance: &str) -> AccountLookup {
    let mut by_file = HashMap::new();
    let mut by_device = HashMap::new();
    let Some(accounts) = store.get("accounts").and_then(Value::as_object) else {
        return AccountLookup { by_file, by_device };
    };

    for (key, account) in accounts {
        if field_str(account, "instance") != instance {
            continue;
        }
        let file_name = field_str(account, "fileName");
        if !file_name.is_empty() {
            by_file.insert(file_name.to_owned(), account.clone());
        }
        if !key.starts_with("legacy:") {
            by_device.insert(key.clone(), account.clone());
        }
    }

    AccountLookup { by_file, by_device }
}

fn metadata_for_xml<'a>(
    lookup: &'a AccountLookup,
    file_name: &str,
    device_account: &str,
) -> Option<&'a Value> {
    if !device_account.is_empty() {
        if let Some(account) = lookup.by_device.get(device_account) {
            return Some(account);
        }
    }

    lookup.by_file.get(file_name)
}

fn used_account_matches(used: &HashSet<String>, file_name: &str, device_account: &str) -> bool {
    if used.contains(file_name) {
        return true;
    }
    if device_account.is_empty() {
        return false;
    }

    let plain_xml = format!("{device_account}.xml");
    let prefixed_xml = format!("_{device_account}.xml");
    used.iter().any(|entry| {
        entry == device_account || entry == &plain_xml || entry.ends_with(&prefixed_xml)
    })
}

fn sort_candidates(candidates: &mut Vec<Candidate>, sort_method: &str) {
    match sort_method {
        "ModifiedDesc" => candidates.sort_by_key(|c| Reverse(c.sort_time.clone())),
        "PacksAsc" => candidates.sort_by_key(|c| (c.pack_count, c.sort_time.clone())),
        "PacksDesc" => candidates.sort_by_key(|c| (Reverse(c.pack_count), c.sort_time.clone())),
        "LastLoginAsc" => candidates.sort_by_key(|c| (c.last_login.clone(), c.sort_time.clone())),
        _ => candidates.sort_by_key(|c| c.sort_time.clone()),
    }
}

fn schedule_accounts(root: &Path, options: ScheduleOptions) -> Result<()> {
    let store = ensure_metadata(root)?;
    let save_dir = saved_dir(root).join(&options.instance);
    fs::create_dir_all(&save_dir)?;

    let list_path = save_dir.join("list.txt");
    let current_path = save_dir.join("list_current.txt");
    let last_generated_path = save_dir.join("list_last_generated.txt");
    let used_state = clean_used_accounts(&save_dir, options.force_clear_used)?;
    let lookup = accounts_for_instance(&store, &options.instance);
    let mut candidates = Vec::new();
    for entry in
        fs::read_dir(&save_dir).with_context(|| format!("Could not read {:?}", save_dir))?
    {
        let path = entry?.path();
        if !path
            .extension()
            .and_then(|ext| ext.to_str())
            .is_some_and(|ext| ext.eq_ignore_ascii_case("xml"))
        {
            continue;
        }

        let file_name = path
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();
        let device_account = extract_device_account_from_xml(&path);
        if used_account_matches(&used_state.used, &file_name, &device_account) {
            continue;
        }

        let fallback = new_account(&options.instance, &file_name, &path);
        let metadata_account = metadata_for_xml(&lookup, &file_name, &device_account);
        let account = metadata_account.unwrap_or(&fallback);
        if !eligible(account, &options) {
            continue;
        }

        let pack_count =
            field_i64(account, "packCount").unwrap_or_else(|| extract_pack_count(&file_name));
        if !pack_count_allowed(
            &options.delete_method,
            metadata_account,
            pack_count,
            options.inject_wonderpick_min_packs,
        ) {
            continue;
        }

        let sort_time = {
            let value = field_str(account, "lastPackPulled");
            if value.is_empty() {
                modified_stamp(&path)
            } else {
                value.to_owned()
            }
        };
        let last_login = {
            let value = field_str(account, "lastLoggedIn");
            if value.is_empty() {
                "0".to_owned()
            } else {
                value.to_owned()
            }
        };

        candidates.push(Candidate {
            file_name,
            sort_time,
            last_login,
            pack_count,
        });
    }

    sort_candidates(&mut candidates, &options.sort_method);

    let list = candidates
        .into_iter()
        .map(|c| c.file_name + "\r\n")
        .collect::<String>();
    fs::write(&list_path, &list)?;
    fs::write(&current_path, &list)?;
    fs::write(
        &last_generated_path,
        Local::now().format("%Y%m%d%H%M%S").to_string(),
    )?;
    println!("{}", list.lines().count());
    remove_used_accounts_backup(used_state);
    Ok(())
}

fn count_eligible_for_all_instances(
    root: &Path,
    store: &Value,
    instances: usize,
    options: &ScheduleOptions,
) -> Result<usize> {
    let mut total = 0usize;

    for instance in 1..=instances {
        let instance_name = instance.to_string();
        let save_dir = saved_dir(root).join(&instance_name);
        if !save_dir.exists() {
            continue;
        }

        let used_state = clean_used_accounts(&save_dir, false)?;
        let lookup = accounts_for_instance(store, &instance_name);

        for entry in
            fs::read_dir(&save_dir).with_context(|| format!("Could not read {:?}", save_dir))?
        {
            let path = entry?.path();
            if !path
                .extension()
                .and_then(|ext| ext.to_str())
                .is_some_and(|ext| ext.eq_ignore_ascii_case("xml"))
            {
                continue;
            }

            let file_name = path
                .file_name()
                .map(|s| s.to_string_lossy().to_string())
                .unwrap_or_default();
            let device_account = extract_device_account_from_xml(&path);
            if used_account_matches(&used_state.used, &file_name, &device_account) {
                continue;
            }

            let fallback = new_account(&instance_name, &file_name, &path);
            let metadata_account = metadata_for_xml(&lookup, &file_name, &device_account);
            let account = metadata_account.unwrap_or(&fallback);
            if !eligible(account, options) {
                continue;
            }

            let pack_count =
                field_i64(account, "packCount").unwrap_or_else(|| extract_pack_count(&file_name));
            if pack_count_allowed(
                &options.delete_method,
                metadata_account,
                pack_count,
                options.inject_wonderpick_min_packs,
            ) {
                total += 1;
            }
        }
    }

    Ok(total)
}

fn remove_path(path: &Path) -> Result<()> {
    if !path.exists() {
        return Ok(());
    }
    if path.is_dir() {
        match fs::remove_dir_all(path) {
            Ok(()) => {}
            Err(err) if err.kind() == ErrorKind::NotFound => {}
            Err(err) => {
                return Err(err).with_context(|| format!("Could not remove directory {:?}", path));
            }
        }
    } else {
        match fs::remove_file(path) {
            Ok(()) => {}
            Err(err) if err.kind() == ErrorKind::NotFound => {}
            Err(err) => {
                return Err(err).with_context(|| format!("Could not remove file {:?}", path));
            }
        }
    }
    Ok(())
}

fn move_replace(from: &Path, to: &Path) -> Result<()> {
    remove_path(to).with_context(|| format!("Could not prepare destination {:?}", to))?;
    if let Some(parent) = to.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("Could not create destination directory {:?}", parent))?;
    }
    fs::rename(from, to).with_context(|| format!("Could not move {:?} to {:?}", from, to))
}

fn is_within(path: &Path, parent: &Path) -> bool {
    let Ok(path) = path.canonicalize() else {
        return false;
    };
    let Ok(parent) = parent.canonicalize() else {
        return false;
    };
    path.starts_with(parent)
}

fn strip_balance_staging_prefix(file_name: &str) -> String {
    let mut current = file_name;

    while current.len() > 9 {
        let Some((prefix, rest)) = current.split_once('_') else {
            break;
        };
        if prefix.len() != 8 || !prefix.chars().all(|ch| ch.is_ascii_digit()) || rest.is_empty() {
            break;
        }
        current = rest;
    }

    current.to_owned()
}

fn collect_xmls_for_balance(
    save_dir: &Path,
    staging_dir: &Path,
    out: &mut Vec<(String, PathBuf)>,
) -> Result<()> {
    if !save_dir.exists() {
        return Ok(());
    }

    fs::create_dir_all(staging_dir)?;
    append_carddb_log(
        save_dir.parent().and_then(Path::parent).unwrap_or(save_dir),
        &format!(
            "collect_xmls_for_balance started; save_dir={:?}; staging_dir={:?}",
            save_dir, staging_dir
        ),
    );
    let mut stack = vec![save_dir.to_path_buf()];
    let mut counter = 0usize;

    while let Some(dir) = stack.pop() {
        append_carddb_log(
            save_dir.parent().and_then(Path::parent).unwrap_or(save_dir),
            &format!("collect_xmls_for_balance scanning {:?}", dir),
        );
        for entry in fs::read_dir(&dir).with_context(|| format!("Could not read {:?}", dir))? {
            let path = entry?.path();
            if path.is_dir() {
                if !is_within(&path, staging_dir) {
                    stack.push(path);
                }
                continue;
            }

            if !path
                .extension()
                .and_then(|ext| ext.to_str())
                .is_some_and(|ext| ext.eq_ignore_ascii_case("xml"))
            {
                continue;
            }

            if is_within(&path, staging_dir) {
                continue;
            }

            let file_name = path
                .file_name()
                .map(|s| s.to_string_lossy().to_string())
                .unwrap_or_default();
            let file_name = strip_balance_staging_prefix(&file_name);
            counter += 1;
            let staging_name = format!("{counter:08}_{file_name}");
            let staging_path = staging_dir.join(staging_name);
            move_replace(&path, &staging_path).with_context(|| {
                format!(
                    "Failed while staging XML #{counter}: source={:?}, staging={:?}",
                    path, staging_path
                )
            })?;
            out.push((file_name, staging_path));
        }
    }

    append_carddb_log(
        save_dir.parent().and_then(Path::parent).unwrap_or(save_dir),
        &format!("collect_xmls_for_balance completed; staged={counter}"),
    );
    Ok(())
}

fn file_created_or_modified(path: &Path) -> std::time::SystemTime {
    fs::metadata(path)
        .and_then(|m| m.created().or_else(|_| m.modified()))
        .unwrap_or(std::time::SystemTime::UNIX_EPOCH)
}

fn pack_counts_by_file(store: &Value) -> HashMap<String, i64> {
    let mut result = HashMap::new();
    let Some(accounts) = store.get("accounts").and_then(Value::as_object) else {
        return result;
    };

    for account in accounts.values() {
        let file_name = field_str(account, "fileName");
        if file_name.is_empty() {
            continue;
        }
        let pack_count =
            field_i64(account, "packCount").unwrap_or_else(|| extract_pack_count(file_name));
        result.insert(file_name.to_owned(), pack_count);
    }

    result
}

fn load_account_files_for_xmls(root: &Path, xmls: &[(String, PathBuf)]) -> Result<Value> {
    let mut store = json!({ "accounts": {} });
    let accounts = store["accounts"].as_object_mut().expect("accounts object");
    let mut seen = HashSet::new();

    for (file_name, path) in xmls {
        let device_account = extract_device_account_from_xml(path);
        if device_account.is_empty() || !seen.insert(device_account.clone()) {
            continue;
        }

        let account_path = account_file_path(root, &device_account);
        let metadata = if account_path.exists() {
            let (_key, metadata) = load_account_file(&account_path, &device_account)?;
            metadata
        } else {
            new_account("", file_name, path)
        };
        accounts.insert(device_account, metadata);
    }

    Ok(ensure_store(store))
}

fn update_metadata_instance(store: &mut Value, file_name: &str, instance: usize, file_path: &Path) {
    let device_account = extract_device_account_from_xml(file_path);
    let accounts = store["accounts"].as_object_mut().expect("accounts object");
    let key = if !device_account.is_empty() {
        device_account.clone()
    } else {
        accounts
            .iter()
            .find(|(_, account)| field_str(account, "fileName") == file_name)
            .map(|(key, _)| key.clone())
            .unwrap_or_else(|| format!("legacy:{instance}/{file_name}"))
    };

    let mut account = accounts
        .remove(&key)
        .unwrap_or_else(|| new_account(&instance.to_string(), file_name, file_path));
    let created_at_empty = field_str(&account, "createdAt").is_empty();
    if let Some(obj) = account.as_object_mut() {
        obj.remove("deviceAccount");
        obj.insert("instance".to_owned(), json!(instance.to_string()));
        obj.insert("fileName".to_owned(), json!(file_name));
        obj.entry("packCount".to_owned())
            .or_insert_with(|| json!(extract_pack_count(file_name)));
        if created_at_empty {
            obj.insert("createdAt".to_owned(), json!(extract_created_at(file_name)));
        }
    }

    let new_key = account_key(&key, &account);
    accounts.insert(new_key, account);
}

fn balance_xmls(root: &Path, instances: usize, options: ScheduleOptions) -> Result<()> {
    append_carddb_log(
        root,
        &format!(
            "balance_xmls entered; instances={instances}; delete_method={}; sort_method={}",
            options.delete_method, options.sort_method
        ),
    );
    if instances == 0 {
        append_carddb_log(root, "balance_xmls skipped because instances=0");
        return Ok(());
    }

    write_balance_progress(root, 1, "Preparing XML balance")?;
    let save_dir = saved_dir(root);
    let tmp_dir = save_dir.join("tmp");
    let staging_dir = tmp_dir.join(format!("balance_{}", Local::now().format("%Y%m%d%H%M%S")));
    append_carddb_log(
        root,
        &format!(
            "balance_xmls preparing directories; save_dir={:?}; tmp_dir={:?}; staging_dir={:?}",
            save_dir, tmp_dir, staging_dir
        ),
    );
    fs::create_dir_all(&save_dir)
        .with_context(|| format!("Could not create save directory {:?}", save_dir))?;
    fs::create_dir_all(&tmp_dir)
        .with_context(|| format!("Could not create tmp directory {:?}", tmp_dir))?;

    write_balance_progress(root, 5, "Importing staged card rows")?;
    append_carddb_log(root, "balance_xmls merging card database");
    merge_card_db(root).context("Failed while importing staged card rows")?;

    for instance in 1..=instances {
        let instance_dir = save_dir.join(instance.to_string());
        fs::create_dir_all(&instance_dir)
            .with_context(|| format!("Could not create instance directory {:?}", instance_dir))?;
        let _ = fs::remove_file(instance_dir.join("list.txt"));
        let _ = fs::remove_file(instance_dir.join("list_current.txt"));
    }

    write_balance_progress(root, 20, "Collecting XML files")?;
    let mut xmls = Vec::new();
    collect_xmls_for_balance(&save_dir, &staging_dir, &mut xmls)
        .context("Failed while collecting XML files for balance")?;
    append_carddb_log(
        root,
        &format!("balance_xmls collected {} XML files", xmls.len()),
    );

    write_balance_progress(root, 28, "Reading metadata for balanced XMLs")?;
    let mut store = if account_files_exist(root) && !legacy_metadata_path(root).exists() {
        append_carddb_log(root, "balance_xmls loading per-account metadata files");
        load_account_files_for_xmls(root, &xmls)
            .context("Failed while loading account metadata for XMLs")?
    } else {
        append_carddb_log(root, "balance_xmls ensuring account metadata");
        ensure_metadata(root).context("Failed while ensuring account metadata")?
    };
    let pack_counts = pack_counts_by_file(&store);
    let mut newest_by_name: HashMap<String, (std::time::SystemTime, PathBuf)> = HashMap::new();

    write_balance_progress(root, 35, "Removing duplicate XML files")?;
    for (file_name, path) in xmls {
        let file_time = file_created_or_modified(&path);
        if let Some((prev_time, prev_path)) = newest_by_name.get(&file_name) {
            if file_time > *prev_time {
                let _ = fs::remove_file(prev_path);
                newest_by_name.insert(file_name, (file_time, path));
            } else {
                let _ = fs::remove_file(&path);
            }
        } else {
            newest_by_name.insert(file_name, (file_time, path));
        }
    }

    let mut files: Vec<_> = newest_by_name
        .into_iter()
        .map(|(file_name, (_time, path))| {
            let pack_count = pack_counts
                .get(&file_name)
                .copied()
                .unwrap_or_else(|| extract_pack_count(&file_name));
            (Reverse(pack_count), file_name, path)
        })
        .collect();
    files.sort_by_key(|(pack_count, file_name, _)| (*pack_count, file_name.clone()));

    write_balance_progress(root, 50, "Distributing XML files")?;
    let total_files = files.len().max(1);
    let mut instance = 1usize;
    for (index, (_pack_count, file_name, path)) in files.into_iter().enumerate() {
        let dest = save_dir.join(instance.to_string()).join(&file_name);
        move_replace(&path, &dest).with_context(|| {
            format!(
                "Failed while distributing XML index={index}, file_name={file_name}, source={:?}, destination={:?}",
                path, dest
            )
        })?;
        update_metadata_instance(&mut store, &file_name, instance, &dest);
        if index % 50 == 0 {
            let percent = 50 + ((index + 1) * 30 / total_files) as u8;
            write_balance_progress(root, percent, "Distributing XML files")?;
        }
        instance += 1;
        if instance > instances {
            instance = 1;
        }
    }

    write_balance_progress(root, 82, "Writing account metadata")?;
    append_carddb_log(root, "balance_xmls writing account metadata files");
    write_account_files_from_store(root, &store)
        .context("Failed while writing account metadata")?;

    write_balance_progress(root, 92, "Counting eligible XML files")?;
    append_carddb_log(root, "balance_xmls counting eligible XML files");
    let eligible_now = count_eligible_for_all_instances(root, &store, instances, &options)
        .context("Failed while counting eligible XML files")?;

    fs::write(
        save_dir.join("balance_result.txt"),
        format!("{eligible_now}\n"),
    )
    .with_context(|| format!("Could not write {:?}", save_dir.join("balance_result.txt")))?;
    let _ = fs::remove_dir_all(&staging_dir);
    write_balance_progress(root, 100, "XML balance complete")?;
    append_carddb_log(
        root,
        &format!("balance_xmls completed; eligible_now={eligible_now}"),
    );
    println!("{eligible_now}");
    Ok(())
}

fn find_account<'a>(
    store: &'a Value,
    device_account: Option<&str>,
    instance: Option<&str>,
    file_name: Option<&str>,
    key: Option<&str>,
) -> Option<(String, &'a Value)> {
    let accounts = store.get("accounts")?.as_object()?;

    if let Some(key) = key {
        if let Some(account) = accounts.get(key) {
            return Some((key.to_owned(), account));
        }
    }

    if let Some(device_account) = device_account {
        if let Some(account) = accounts.get(device_account) {
            return Some((device_account.to_owned(), account));
        }
        let legacy_device_key = format!("deviceAccount:{device_account}");
        if let Some(account) = accounts.get(&legacy_device_key) {
            return Some((device_account.to_owned(), account));
        }
    }

    for (candidate_key, account) in accounts {
        let key_device = candidate_key
            .strip_prefix("deviceAccount:")
            .unwrap_or(candidate_key);
        let candidate_device = account
            .get("deviceAccount")
            .and_then(Value::as_str)
            .unwrap_or(key_device);
        if device_account.is_some() && Some(candidate_device) == device_account {
            return Some((account_key(candidate_key, account), account));
        }

        let candidate_instance = account.get("instance").and_then(Value::as_str);
        let candidate_file = account.get("fileName").and_then(Value::as_str);
        if instance.is_some()
            && file_name.is_some()
            && candidate_instance == instance
            && candidate_file == file_name
        {
            return Some((account_key(candidate_key, account), account));
        }
    }

    None
}

fn extract_metadata(
    root: &Path,
    device_account: Option<String>,
    instance: Option<String>,
    file_name: Option<String>,
    key: Option<String>,
    output: &Path,
) -> Result<()> {
    let store = ensure_metadata(root)?;
    let mut out = json!({ "accounts": {} });

    if let Some((found_key, account)) = find_account(
        &store,
        device_account.as_deref(),
        instance.as_deref(),
        file_name.as_deref(),
        key.as_deref(),
    ) {
        out["accounts"]
            .as_object_mut()
            .expect("accounts object")
            .insert(found_key, account.clone());
    }

    write_store(output, &out)
}

fn clear_flag(root: &Path, flag: &str) -> Result<()> {
    let dir = account_files_dir(root);
    let mut changed = 0usize;

    if dir.exists() {
        write_clear_flag_progress(root, 1, "Preparing reset")?;
        let mut paths = Vec::new();
        for entry in fs::read_dir(&dir).with_context(|| format!("Could not read {:?}", dir))? {
            let path = entry?.path();
            if !path
                .extension()
                .and_then(|e| e.to_str())
                .is_some_and(|e| e.eq_ignore_ascii_case("json"))
            {
                continue;
            }
            paths.push(path);
        }
        paths.sort();

        let total = paths.len().max(1);
        write_clear_flag_progress(root, 5, "Scanning account files")?;
        for (index, path) in paths.into_iter().enumerate() {
            let fallback = account_key_from_file(&path).unwrap_or_default();
            let mut doc = load_account_document(&path, &fallback)?;
            let Some(metadata) = doc.get_mut("metadata").and_then(Value::as_object_mut) else {
                if index % 50 == 0 {
                    let percent = 5 + ((index + 1) * 90 / total) as u8;
                    write_clear_flag_progress(root, percent, "Resetting account status")?;
                }
                continue;
            };
            let Some(flags) = metadata.get_mut("flags").and_then(Value::as_object_mut) else {
                if index % 50 == 0 {
                    let percent = 5 + ((index + 1) * 90 / total) as u8;
                    write_clear_flag_progress(root, percent, "Resetting account status")?;
                }
                continue;
            };
            let active = flags
                .get(flag)
                .and_then(|value| value.get("value"))
                .map(|value| value.as_bool().unwrap_or(false) || value.as_i64().unwrap_or(0) != 0)
                .unwrap_or(false);

            if active {
                flags.remove(flag);
                if flags.is_empty() {
                    metadata.remove("flags");
                }
                let device_account = doc
                    .get("deviceAccount")
                    .and_then(Value::as_str)
                    .unwrap_or(&fallback)
                    .to_owned();
                write_account_document(root, &device_account, &doc)?;
                changed += 1;
            }
            if index % 50 == 0 {
                let percent = 5 + ((index + 1) * 90 / total) as u8;
                write_clear_flag_progress(root, percent, "Resetting account status")?;
            }
        }
    }

    fs::create_dir_all(saved_dir(root))?;
    fs::write(
        saved_dir(root).join("clear_flag_result.txt"),
        format!("{changed}\n"),
    )?;
    write_clear_flag_progress(root, 100, "Reset complete")?;
    println!("{changed}");
    Ok(())
}

fn parse_pull_timestamp(timestamp: &str) -> Option<DateTime<Utc>> {
    let timestamp = timestamp.trim();
    if timestamp.is_empty() || timestamp == "0" {
        return None;
    }

    if timestamp.chars().all(|c| c.is_ascii_digit()) {
        if timestamp.len() == 14 {
            return NaiveDateTime::parse_from_str(timestamp, "%Y%m%d%H%M%S")
                .ok()
                .and_then(|dt| Local.from_local_datetime(&dt).single())
                .map(|dt| dt.with_timezone(&Utc));
        }
        if let Ok(seconds) = timestamp.parse::<i64>() {
            return Utc.timestamp_opt(seconds, 0).single();
        }
    }

    NaiveDateTime::parse_from_str(timestamp, "%Y-%m-%d %H:%M:%S")
        .ok()
        .and_then(|dt| Local.from_local_datetime(&dt).single())
        .map(|dt| dt.with_timezone(&Utc))
}

fn format_pull_timestamp(timestamp: DateTime<Utc>) -> String {
    timestamp
        .with_timezone(&Local)
        .format("%Y-%m-%d %H:%M:%S")
        .to_string()
}

fn normalize_pull_timestamp(timestamp: &str) -> Option<String> {
    parse_pull_timestamp(timestamp).map(format_pull_timestamp)
}

fn oldest_pull_timestamp(doc: &Value) -> Option<DateTime<Utc>> {
    doc.get("pulls")
        .and_then(Value::as_array)?
        .iter()
        .filter_map(|pull| pull.get("timestamp").and_then(Value::as_str))
        .filter_map(parse_pull_timestamp)
        .min()
}

fn cardmap_path(root: &Path) -> PathBuf {
    root.join("Helper").join("cardmap.json")
}

fn ensure_cardmap(root: &Path) -> Result<PathBuf> {
    let path = cardmap_path(root);
    if path.exists() && fs::metadata(&path)?.len() > 0 {
        return Ok(path);
    }

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    let url = "https://leanny.github.io/pocket_tcg_resources/data/cardmap.json";
    let script = format!(
        "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '{}' -OutFile '{}'",
        url,
        path.to_string_lossy().replace('\'', "''")
    );
    let status = ProcessCommand::new("powershell")
        .args([
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            &script,
        ])
        .status()
        .with_context(|| format!("Could not download cardmap.json to {:?}", path))?;

    if !status.success() || !path.exists() || fs::metadata(&path)?.len() == 0 {
        anyhow::bail!("Could not download cardmap.json from {}", url);
    }

    Ok(path)
}

fn value_str<'a>(value: &'a Value, keys: &[&str]) -> Option<&'a str> {
    for key in keys {
        if let Some(text) = value
            .get(*key)
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
        {
            return Some(text);
        }
    }
    None
}

fn insert_cardmap_entry(map: &mut HashMap<String, String>, key: Option<&str>, value: &Value) {
    if let Some(expansion) = value.as_str().filter(|s| !s.is_empty()) {
        if let Some(card_id) = key.filter(|s| !s.is_empty()) {
            map.insert(card_id.to_owned(), expansion.to_owned());
        }
        return;
    }

    let Some(obj) = value.as_object() else {
        return;
    };
    let expansion = value_str(
        value,
        &[
            "ExpansionID",
            "expansionID",
            "expansionId",
            "ExpansionId",
            "pack",
            "Pack",
        ],
    );
    let Some(expansion) = expansion else {
        return;
    };

    if let Some(card_id) = key.filter(|s| !s.is_empty()) {
        map.insert(card_id.to_owned(), expansion.to_owned());
    }
    for field in ["CardID", "cardID", "cardId", "id", "ID"] {
        if let Some(card_id) = obj
            .get(field)
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
        {
            map.insert(card_id.to_owned(), expansion.to_owned());
        }
    }
}

fn collect_cardmap_entries(map: &mut HashMap<String, String>, value: &Value) {
    match value {
        Value::Object(obj) => {
            for (key, entry) in obj {
                insert_cardmap_entry(map, Some(key), entry);
                if entry.is_array() {
                    collect_cardmap_entries(map, entry);
                }
            }
        }
        Value::Array(items) => {
            for entry in items {
                insert_cardmap_entry(map, None, entry);
                collect_cardmap_entries(map, entry);
            }
        }
        _ => {}
    }
}

fn load_cardmap(root: &Path) -> Result<HashMap<String, String>> {
    let path = ensure_cardmap(root)?;
    let text = fs::read_to_string(&path).with_context(|| format!("Could not read {:?}", path))?;
    let value: Value = serde_json::from_str(text.trim_start_matches('\u{feff}'))
        .with_context(|| format!("Could not parse cardmap.json at {:?}", path))?;
    let mut map = HashMap::new();
    collect_cardmap_entries(&mut map, &value);
    Ok(map)
}

fn history_pulls_from_line(
    line: &str,
    cardmap: &HashMap<String, String>,
) -> Option<(DateTime<Utc>, Vec<Value>)> {
    let line = line.trim().trim_start_matches('\u{feff}');
    if line.is_empty() {
        return None;
    }

    let (timestamp, cards_text) = line.split_once('|')?;
    let timestamp = timestamp.trim();
    if timestamp.is_empty() {
        return None;
    }
    let parsed_timestamp = parse_pull_timestamp(timestamp)?;
    let timestamp = format_pull_timestamp(parsed_timestamp);

    let mut cards_by_pack: BTreeMap<String, Vec<Value>> = BTreeMap::new();
    for card in cards_text
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        let pack = cardmap
            .get(card)
            .cloned()
            .unwrap_or_else(|| "unknown".to_owned());
        cards_by_pack.entry(pack).or_default().push(json!(card));
    }

    if cards_by_pack.is_empty() {
        return None;
    }

    let pulls = cards_by_pack
        .into_iter()
        .map(|(pack, cards)| {
            json!({
                "timestamp": timestamp,
                "pack": pack,
                "cards": cards,
            })
        })
        .collect();

    Some((parsed_timestamp, pulls))
}

fn set_doc_flag(doc: &mut Value, flag: &str) {
    let now = Local::now().format("%Y%m%d%H%M%S").to_string();
    if !doc["metadata"].is_object() {
        doc["metadata"] = json!({});
    }
    if !doc["metadata"]["flags"].is_object() {
        doc["metadata"]["flags"] = json!({});
    }
    doc["metadata"]["flags"][flag] = new_flag(1, &now, "");
}

fn import_history(root: &Path, device_account: &str, input: &Path) -> Result<()> {
    if device_account.trim().is_empty() {
        return Ok(());
    }

    let account_path = account_file_path(root, device_account);
    let mut doc = load_account_document(&account_path, device_account)?;
    if !doc["pulls"].is_array() {
        doc["pulls"] = json!([]);
    }
    let oldest_existing = oldest_pull_timestamp(&doc);
    let history_cutoff = oldest_existing.map(|timestamp| timestamp - Duration::hours(24));
    let cardmap = load_cardmap(root)?;

    if input.exists() {
        let text = fs::read_to_string(input)
            .with_context(|| format!("Could not read history file {:?}", input))?;
        for line in text.lines() {
            if let Some((timestamp, pulls)) = history_pulls_from_line(line, &cardmap) {
                if history_cutoff
                    .map(|cutoff| timestamp > cutoff)
                    .unwrap_or(false)
                {
                    continue;
                }
                doc["pulls"]
                    .as_array_mut()
                    .expect("pulls array")
                    .extend(pulls);
            }
        }
    }

    set_doc_flag(&mut doc, "H");
    write_account_document(root, device_account, &doc)?;
    Ok(())
}

fn append_pull(
    root: &Path,
    device_account: &str,
    timestamp: &str,
    pack: &str,
    cards_text: &str,
) -> Result<()> {
    if device_account.trim().is_empty() {
        return Ok(());
    }

    let cards: Vec<Value> = cards_text
        .split('|')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| json!(s))
        .collect();

    let pull = json!({
        "timestamp": normalize_pull_timestamp(timestamp).unwrap_or_else(|| timestamp.trim().to_owned()),
        "pack": pack,
        "cards": cards,
    });
    append_pull_to_account_file(root, device_account, pull)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_pull_timestamp_inputs_to_display_format() {
        assert_eq!(
            normalize_pull_timestamp("2026-05-11 20:00:00").as_deref(),
            Some("2026-05-11 20:00:00")
        );
        assert_eq!(
            normalize_pull_timestamp("20260511200000").as_deref(),
            Some("2026-05-11 20:00:00")
        );
    }

    #[test]
    fn csv_rows_with_multiple_packs_split_by_cardmap_expansion() {
        let fields = parse_csv_line(
            "\"2026-05-05 04:53:46\",\"dev\",\"A4b, A4b, B1, B2, B2\",\"CARD_A|CARD_B|CARD_C|CARD_D|CARD_E\"",
        );
        let cardmap = HashMap::from([
            ("CARD_A".to_owned(), "B2".to_owned()),
            ("CARD_B".to_owned(), "A4b".to_owned()),
            ("CARD_C".to_owned(), "B2".to_owned()),
            ("CARD_D".to_owned(), "B1".to_owned()),
            ("CARD_E".to_owned(), "A4b".to_owned()),
        ]);

        let (device_account, pulls) = pulls_from_fields(&fields, Some(&cardmap)).expect("pulls");

        assert_eq!(device_account, "dev");
        assert_eq!(pulls.len(), 3);
        assert_eq!(pulls[0]["pack"], "A4b");
        assert_eq!(pulls[0]["cards"].as_array().unwrap().len(), 2);
        assert_eq!(pulls[1]["pack"], "B1");
        assert_eq!(pulls[1]["cards"].as_array().unwrap().len(), 1);
        assert_eq!(pulls[2]["pack"], "B2");
        assert_eq!(pulls[2]["cards"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn csv_rows_with_single_pack_keep_legacy_single_pull() {
        let fields =
            parse_csv_line("\"2026-05-05 04:53:46\",\"dev\",\"A4b\",\"CARD_A|CARD_B|CARD_C\"");

        let (_device_account, pulls) = pulls_from_fields(&fields, None).expect("pulls");

        assert_eq!(pulls.len(), 1);
        assert_eq!(pulls[0]["pack"], "A4b");
        assert_eq!(pulls[0]["cards"].as_array().unwrap().len(), 3);
    }

    #[test]
    fn prefixed_duplicate_xml_uses_device_account_metadata() {
        let device_account = "a47fba5b1186e05e";
        let recent_pull = Local::now().format("%Y%m%d%H%M%S").to_string();
        let store = json!({
            "accounts": {
                device_account: {
                    "instance": "1",
                    "fileName": "a47fba5b1186e05e.xml",
                    "packCount": 34,
                    "lastPackPulled": recent_pull,
                    "flags": {}
                }
            }
        });
        let lookup = accounts_for_instance(&store, "1");

        let metadata = metadata_for_xml(&lookup, "00000035_a47fba5b1186e05e.xml", device_account)
            .expect("metadata by device account");

        assert_eq!(field_str(metadata, "fileName"), "a47fba5b1186e05e.xml");
        assert!(!eligible(
            metadata,
            &ScheduleOptions {
                instance: "1".to_owned(),
                delete_method: "Inject 13P+".to_owned(),
                sort_method: "ModifiedAsc".to_owned(),
                inject_wonderpick_min_packs: 96,
                wonderpick_for_event_missions: false,
                claim_special_missions: false,
                receive_gift: false,
                ocr_shinedust: false,
                s4t_enabled: false,
                spend_hourglass: false,
                force_clear_used: false,
            }
        ));

        let used = HashSet::from(["a47fba5b1186e05e.xml".to_owned()]);
        assert!(used_account_matches(
            &used,
            "00000035_a47fba5b1186e05e.xml",
            device_account
        ));
    }

    #[test]
    fn last_login_sort_orders_unset_login_first_then_oldest_login() {
        let mut candidates = vec![
            Candidate {
                file_name: "recent.xml".to_owned(),
                sort_time: "20260503000000".to_owned(),
                last_login: "20260505000000".to_owned(),
                pack_count: 20,
            },
            Candidate {
                file_name: "unset.xml".to_owned(),
                sort_time: "20260502000000".to_owned(),
                last_login: "0".to_owned(),
                pack_count: 30,
            },
            Candidate {
                file_name: "old.xml".to_owned(),
                sort_time: "20260501000000".to_owned(),
                last_login: "20260504000000".to_owned(),
                pack_count: 10,
            },
        ];

        sort_candidates(&mut candidates, "LastLoginAsc");

        let names = candidates
            .iter()
            .map(|candidate| candidate.file_name.as_str())
            .collect::<Vec<_>>();
        assert_eq!(names, vec!["unset.xml", "old.xml", "recent.xml"]);
    }
}
