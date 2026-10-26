import { createClient } from "npm:@supabase/supabase-js@2";

const projectUrl = Deno.env.get("SUPABASE_URL") || "";
const secrets = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
const key = secrets.default || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const admin = createClient(projectUrl, key, { auth: { persistSession: false, autoRefreshToken: false } });
const bucket = "bestmom-survey-backups";
const permittedOrigin = "https://bestmom353535-design.github.io";

function cors(req) {
  const origin = req.headers.get("origin");
  return origin === permittedOrigin ? {
    "Access-Control-Allow-Origin": permittedOrigin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Vary": "Origin"
  } : {};
}
function reply(req, body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...cors(req) }
  });
}
function koreaDate() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul", year: "numeric", month: "2-digit", day: "2-digit"
  }).formatToParts(new Date());
  const part = (name) => parts.find(x => x.type === name)?.value || "";
  return part("year") + "-" + part("month") + "-" + part("day");
}
async function allSurveyRows() {
  const all = [];
  for (let offset = 0; offset < 100000; offset += 1000) {
    const { data, error } = await admin.from("bestmom_responses")
      .select("id,created_at,service_year,service_month,city,source,source_other,comment,answers,client_token,respondent_name,birth_date,identity_consent_at")
      .order("id", { ascending: true }).range(offset, offset + 999);
    if (error) throw error;
    all.push(...(data || []));
    if (!data || data.length < 1000) break;
    if (all.length >= 100000) throw new Error("Backup safety limit reached; contact administrator.");
  }
  return all;
}
async function retention(prefix, keepDays) {
  const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 1000, sortBy: { column: "name", order: "asc" } });
  if (error) throw error;
  const now = Date.now();
  let obsolete = [];
  for (const f of data || []) {
    const name = f.name || "";
    if (prefix === "daily" && /^\d{4}-\d{2}-\d{2}\.json$/.test(name)) {
      const ts = Date.parse(name.slice(0, 10) + "T00:00:00Z");
      if (Number.isFinite(ts) && now - ts > keepDays * 86400000) obsolete.push(prefix + "/" + name);
    } else if (prefix === "monthly" && /^\d{4}-\d{2}\.json$/.test(name)) {
      const ts = Date.parse(name.slice(0, 7) + "-01T00:00:00Z");
      if (Number.isFinite(ts) && now - ts > keepDays * 86400000) obsolete.push(prefix + "/" + name);
    }
  }
  if (obsolete.length) {
    const result = await admin.storage.from(bucket).remove(obsolete);
    if (result.error) throw result.error;
  }
  return obsolete.length;
}
async function createBackup() {
  const date = koreaDate();
  const rows = await allSurveyRows();
  const backup = {
    type: "bestmom_survey_backup_v1",
    project: "bestmom-survey",
    created_at: new Date().toISOString(),
    service_timezone: "Asia/Seoul",
    response_count: rows.length,
    records: rows
  };
  const blob = new Blob([JSON.stringify(backup)], { type: "application/json" });
  const dailyPath = "daily/" + date + ".json";
  const u = await admin.storage.from(bucket).upload(dailyPath, blob, {
    contentType: "application/json", upsert: true, cacheControl: "0"
  });
  if (u.error) throw u.error;
  const paths = [dailyPath];
  if (date.endsWith("-01")) {
    const previousMonth = new Date(date.slice(0, 7) + "-01T00:00:00Z");
    previousMonth.setUTCDate(0);
    const monthlyPath = "monthly/" + previousMonth.toISOString().slice(0, 7) + ".json";
    const monthUpload = await admin.storage.from(bucket).upload(monthlyPath, blob, {
      contentType: "application/json", upsert: true, cacheControl: "0"
    });
    if (monthUpload.error) throw monthUpload.error;
    paths.push(monthlyPath);
  }
  const deleted = [];
  for (const [name, days] of [["daily", 45], ["monthly", 760]]) {
    try { deleted.push({ type: name, count: await retention(name, days) }); }
    catch (e) { console.error("Backup retention failed", name, String(e)); }
  }
  return { ok: true, count: rows.length, date, paths, obsolete_removed: deleted };
}
async function listBackups() {
  const results = await Promise.all(["daily", "monthly"].map(p => admin.storage.from(bucket)
    .list(p, { limit: 200, sortBy: { column: "name", order: "desc" } })));
  if (results.some(x => x.error)) throw results.find(x => x.error)?.error;
  const entries = [];
  ["daily", "monthly"].forEach((kind, i) => {
    for (const f of results[i].data || []) {
      if ((kind === "daily" && /^\d{4}-\d{2}-\d{2}\.json$/.test(f.name))
        || (kind === "monthly" && /^\d{4}-\d{2}\.json$/.test(f.name))) {
        entries.push({ path: kind + "/" + f.name, kind,
          created_at: f.created_at || null, size: f.metadata?.size || null });
      }
    }
  });
  entries.sort((a,b) => b.path.localeCompare(a.path));
  return entries;
}
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(req) });
  try {
    if (req.method === "POST") {
      const secret = req.headers.get("x-bestmom-scheduler-token") || "";
      if (secret.length < 100) return reply(req, { error: "Unauthorized" }, 401);
      const result = await admin.rpc("bestmom_verify_backup_cron_token", { p_token: secret });
      if (result.error || result.data !== true) return reply(req, { error: "Unauthorized" }, 401);
      return reply(req, await createBackup());
    }
    if (req.method !== "GET") return reply(req, { error: "Method not allowed" }, 405);
    const bearer = req.headers.get("authorization") || "";
    const jwt = bearer.match(/^Bearer (.+)$/i)?.[1];
    if (!jwt) return reply(req, { error: "Login required" }, 401);
    const { data, error } = await admin.auth.getUser(jwt);
    if (error || !data?.user || data.user.email?.toLowerCase() !== "bestmom353535@gmail.com"
      || !data.user.email_confirmed_at) return reply(req, { error: "Admin only" }, 403);
    const url = new URL(req.url);
    const action = url.searchParams.get("action") || "list";
    if (action === "list") return reply(req, { ok: true, backups: await listBackups() });
    if (action === "download") {
      const file = url.searchParams.get("file") || "";
      if (!/^(daily\/\d{4}-\d{2}-\d{2}|monthly\/\d{4}-\d{2})\.json$/.test(file))
        return reply(req, { error: "Invalid backup path" }, 400);
      const { data: blob, error: fileError } = await admin.storage.from(bucket).download(file);
      if (fileError || !blob) return reply(req, { error: "Backup file not found" }, 404);
      return new Response(blob, { status: 200, headers: {
        "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store",
        "Content-Disposition": 'attachment; filename="bestmom-survey-' + file.replace("/", "-") + '"',
        ...cors(req)
      } });
    }
    return reply(req, { error: "Unknown action" }, 400);
  } catch (e) {
    console.error("Bestmom backup error:", String(e));
    return reply(req, { error: "Backup service temporarily unavailable" }, 500);
  }
});
