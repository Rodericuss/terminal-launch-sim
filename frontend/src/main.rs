mod protocol;

use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};
use protocol::EngineClient;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span, Text};
use ratatui::widgets::{Block, Borders, Clear, Paragraph, Wrap};
use serde_json::{Value, json};
use std::io;

#[derive(Clone, Copy)]
enum Palette {
    Amber,
    Green,
    Mono,
}

impl Palette {
    fn next(self) -> Self {
        match self {
            Self::Amber => Self::Green,
            Self::Green => Self::Mono,
            Self::Mono => Self::Amber,
        }
    }
    fn color(self) -> Color {
        match self {
            Self::Amber => Color::Yellow,
            Self::Green => Color::Green,
            Self::Mono => Color::Reset,
        }
    }
    fn name(self) -> &'static str {
        match self {
            Self::Amber => "ÂMBAR",
            Self::Green => "VERDE",
            Self::Mono => "SEM COR",
        }
    }
}

#[derive(Clone, Copy)]
enum Panel {
    Mission,
    Telemetry,
    Log,
    Research,
}

impl Panel {
    fn next(self) -> Self {
        match self {
            Self::Mission => Self::Telemetry,
            Self::Telemetry => Self::Log,
            Self::Log => Self::Research,
            Self::Research => Self::Mission,
        }
    }
    fn name(self) -> &'static str {
        match self {
            Self::Mission => "MISSÃO",
            Self::Telemetry => "TELEMETRIA",
            Self::Log => "EVENTOS",
            Self::Research => "PESQUISA",
        }
    }
}

struct App {
    engine: EngineClient,
    snapshot: Option<Value>,
    profile: Option<Value>,
    run_id: Option<String>,
    seq: u64,
    mode: Option<String>,
    input: String,
    logs: Vec<String>,
    status: String,
    palette: Palette,
    panel: Panel,
    help: bool,
    quit: bool,
}

impl App {
    fn new(mut engine: EngineClient) -> Self {
        let status = match engine.request("catalog.list", None, 0, json!({})) {
            Ok(data) => format!(
                "Motor conectado · modelo {}",
                data["model_version"].as_str().unwrap_or("?")
            ),
            Err(e) => format!("Falha de catálogo: {e}"),
        };
        let profile = engine
            .request("tech.status", None, 0, json!({}))
            .ok()
            .map(|data| data["profile"].clone());
        Self {
            engine,
            snapshot: None,
            profile,
            run_id: None,
            seq: 0,
            mode: None,
            input: String::new(),
            logs: Vec::new(),
            status,
            palette: Palette::Amber,
            panel: Panel::Mission,
            help: false,
            quit: false,
        }
    }

    fn start(&mut self, mode: &str, seed: u64) {
        match self
            .engine
            .request("run.create", None, 0, json!({"mode": mode, "seed": seed}))
        {
            Ok(data) => {
                self.mode = Some(mode.into());
                self.logs.clear();
                self.accept_snapshot(&data);
                self.status = format!("Missão iniciada: {} · semente {seed}", mode_title(mode));
            }
            Err(e) => self.status = e,
        }
    }

    fn accept_snapshot(&mut self, data: &Value) {
        let Some(snapshot) = data.get("snapshot") else {
            self.status = "Resposta sem snapshot".into();
            return;
        };
        self.run_id = snapshot["run_id"].as_str().map(str::to_owned);
        self.seq = snapshot["seq"].as_u64().unwrap_or(self.seq);
        if let Some(events) = snapshot["events"].as_array() {
            for event in events {
                self.logs.push(format_event(event));
            }
            if self.logs.len() > 200 {
                self.logs.drain(..self.logs.len() - 200);
            }
        }
        self.snapshot = Some(snapshot.clone());
    }

    fn refresh(&mut self) {
        let Some(run_id) = self.run_id.clone() else {
            return;
        };
        match self
            .engine
            .request("run.snapshot", Some(&run_id), self.seq, json!({}))
        {
            Ok(data) => {
                self.accept_snapshot(&data);
                self.status = "Instrumentos sincronizados".into();
            }
            Err(e) => self.status = e,
        }
    }

    fn refresh_profile(&mut self) {
        match self.engine.request("tech.status", None, 0, json!({})) {
            Ok(data) => {
                self.profile = Some(data["profile"].clone());
                self.panel = Panel::Research;
                self.status = "Pesquisa sincronizada".into();
            }
            Err(e) => self.status = e,
        }
    }

    fn unlock_technology(&mut self, id: &str) {
        match self
            .engine
            .request("tech.unlock", None, 0, json!({"id": id}))
        {
            Ok(data) => {
                self.profile = Some(data["profile"].clone());
                self.panel = Panel::Research;
                self.status = format!("Tecnologia {id} desbloqueada; ativa nas próximas missões");
            }
            Err(e) => self.status = e,
        }
    }

    fn submit(&mut self) {
        let command = self.input.trim().to_lowercase();
        self.input.clear();
        if command.is_empty() {
            return;
        }
        if command == "help" || command == "ajuda" {
            self.help = true;
            return;
        }
        if command == "quit" || command == "sair" {
            self.quit = true;
            return;
        }
        if command == "snapshot" || command == "refresh" {
            self.refresh();
            return;
        }
        if command == "tech" || command == "pesquisa" {
            self.refresh_profile();
            return;
        }
        if command == "research filter" || command == "pesquisar filtro" {
            self.unlock_technology("filter");
            return;
        }
        if command == "research network" || command == "pesquisar rede" {
            self.unlock_technology("network");
            return;
        }
        let parts: Vec<&str> = command.split_whitespace().collect();
        if matches!(parts.first(), Some(&"space" | &"central")) && parts.len() <= 2 {
            let seed = if parts.len() == 1 {
                Some(42)
            } else {
                parts[1].parse::<u64>().ok()
            };
            if let Some(seed) = seed {
                self.start(parts[0], seed);
            } else {
                self.status = "Uso: space [SEMENTE] | central [SEMENTE]".into();
            }
            return;
        }
        if command.starts_with("calc ") {
            self.calculate(&command);
            return;
        }
        let Some(run_id) = self.run_id.clone() else {
            self.status = "Escolha um modo: tecla 1 ou 2".into();
            return;
        };
        self.logs
            .push(format!("t={:>3} > {command}", self.time_s()));
        match self.engine.request(
            "run.command",
            Some(&run_id),
            self.seq,
            json!({"command": command}),
        ) {
            Ok(data) => {
                self.accept_snapshot(&data);
                let earned = data["research_points_earned"].as_u64().unwrap_or(0);
                if earned > 0 {
                    self.profile = self
                        .engine
                        .request("tech.status", None, 0, json!({}))
                        .ok()
                        .map(|reply| reply["profile"].clone());
                    self.status = format!("Missão concluída · +{earned} ponto(s) de pesquisa");
                } else {
                    self.status = format!("Comando aceito · sequência {}", self.seq);
                }
            }
            Err(e) => {
                self.logs.push(format!("REJEITADO: {e}"));
                self.status = e.clone();
                if e.starts_with("sequence_mismatch:") {
                    self.refresh();
                }
            }
        }
    }

    fn calculate(&mut self, command: &str) {
        let parts: Vec<&str> = command.split_whitespace().collect();
        let payload = match parts.as_slice() {
            ["calc", "speed", distance, seconds] => {
                let (Ok(distance), Ok(seconds)) = (distance.parse::<f64>(), seconds.parse::<f64>())
                else {
                    self.status = "Uso: calc speed DISTÂNCIA_M TEMPO_S".into();
                    return;
                };
                json!({"model":"average_speed","inputs":{"distance_m":distance,"time_s":seconds}})
            }
            ["calc", "eta", remaining, teams] => {
                let (Ok(remaining), Ok(teams)) = (remaining.parse::<u64>(), teams.parse::<u64>())
                else {
                    self.status = "Uso: calc eta TRABALHO_RESTANTE EQUIPES".into();
                    return;
                };
                json!({"model":"work_eta","inputs":{"remaining_work":remaining,"teams":teams}})
            }
            _ => {
                self.status = "Calculadora: calc speed 100 20 | calc eta 4 2".into();
                return;
            }
        };
        match self.engine.request(
            "calculator.evaluate",
            self.run_id.as_deref(),
            self.seq,
            payload,
        ) {
            Ok(data) => {
                let result = &data["result"];
                let value = format_number(&result["value"]);
                let unit = result["unit"].as_str().unwrap_or("");
                let explanation = result["explanation"].as_str().unwrap_or("");
                let line = format!("CÁLCULO {value} {unit} · {explanation}");
                self.logs.push(line.clone());
                self.status = line;
                self.panel = Panel::Log;
            }
            Err(e) => self.status = e,
        }
    }

    fn time_s(&self) -> u64 {
        self.snapshot
            .as_ref()
            .and_then(|s| s["observation"]["time_s"].as_u64())
            .unwrap_or(0)
    }

    fn on_key(&mut self, key: KeyEvent) {
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            self.quit = true;
            return;
        }
        match key.code {
            KeyCode::F(1) => self.help = !self.help,
            KeyCode::F(2) => self.palette = self.palette.next(),
            KeyCode::F(3) | KeyCode::Tab => self.panel = self.panel.next(),
            KeyCode::Esc => {
                self.help = false;
                self.input.clear();
            }
            KeyCode::Enter => {
                if self.help {
                    self.help = false;
                } else {
                    self.submit();
                }
            }
            KeyCode::Backspace => {
                self.input.pop();
            }
            KeyCode::Char('1') if self.mode.is_none() && self.input.is_empty() => {
                self.start("space", 42)
            }
            KeyCode::Char('2') if self.mode.is_none() && self.input.is_empty() => {
                self.start("central", 42)
            }
            KeyCode::Char(c) if !self.help => self.input.push(c),
            _ => {}
        }
    }
}

fn mode_title(mode: &str) -> &'static str {
    match mode {
        "space" => "PROGRAMA ESPACIAL",
        "central" => "CENTRAL FICTÍCIA",
        _ => "MISSÃO",
    }
}

fn format_number(value: &Value) -> String {
    if let Some(n) = value.as_i64() {
        n.to_string()
    } else if let Some(n) = value.as_u64() {
        n.to_string()
    } else if let Some(n) = value.as_f64() {
        format!("{n:.1}")
    } else {
        value.to_string()
    }
}

fn format_event(event: &Value) -> String {
    let time = event["time_s"].as_u64().unwrap_or(0);
    let kind = event["type"].as_str().unwrap_or("evento");
    let mut detail = event["contact"]
        .as_str()
        .or_else(|| event["result"].as_str())
        .unwrap_or("")
        .to_string();
    if let Some(metres) = event["difference_m"].as_u64() {
        detail = format!("{metres} m");
    }
    if let Some(seconds) = event["remaining_s"].as_u64() {
        detail = format!("{detail} · {seconds} s restantes");
    }
    format!(
        "t={time:>3}  {} {}",
        kind.replace('_', " ").to_uppercase(),
        detail
    )
}

fn field(o: &Value, key: &str, label: &str, unit: &str) -> String {
    let value = &o[key];
    let rendered = if value.is_string() {
        value.as_str().unwrap_or("?").to_string()
    } else if value.is_boolean() {
        if value.as_bool().unwrap_or(false) {
            "SIM".into()
        } else {
            "NÃO".into()
        }
    } else {
        format_number(value)
    };
    format!("{label:<21} {rendered:>8} {unit}")
}

fn telemetry_lines(o: &Value) -> Vec<String> {
    let mut lines = vec![
        field(o, "time_s", "TEMPO", "s"),
        field(o, "status", "ESTADO", ""),
    ];
    if o["mode"] == "space" {
        lines.extend([
            field(o, "phase", "FASE", ""),
            field(o, "altitude_m", "ALTITUDE OBS.", "m"),
            field(o, "altitude_uncertainty_m", "INCERTEZA ±", "m"),
            field(o, "velocity_m_s", "VELOCIDADE OBS.", "m/s"),
            field(o, "fuel_kg", "COMBUSTÍVEL", "kg"),
            field(o, "peak_altitude_m", "APOGEU", "m"),
            field(o, "target_altitude_m", "META", "m"),
            field(o, "check_complete", "CHECAGEM", ""),
        ]);
        if o["sensor_disagreement_m"].is_number() {
            lines.push(field(o, "sensor_disagreement_m", "DIVERGÊNCIA", "m"));
        }
    } else {
        lines.extend([
            field(o, "available_teams", "EQUIPES LIVRES", ""),
            field(o, "deadline_uncertainty_s", "INCERTEZA ±", "s"),
        ]);
        if o["network_monitoring"] == true {
            lines.push("MALHA DE SENSORES      ATIVA".into());
        }
        if let Some(contacts) = o["contacts"].as_array() {
            for c in contacts {
                lines.push(String::new());
                lines.push(format!(
                    "{} · {}",
                    c["label"].as_str().unwrap_or("CONTATO"),
                    c["status"].as_str().unwrap_or("?")
                ));
                lines.push(format!(
                    "  avanço {}/{} · equipes {} · prazo estimado {} s",
                    format_number(&c["work"]),
                    format_number(&c["work_required"]),
                    format_number(&c["assigned"]),
                    format_number(&c["estimated_remaining_s"])
                ));
            }
        }
    }
    lines
}

fn mission_lines(o: &Value) -> Vec<String> {
    if o["mode"] == "space" {
        let phase = o["phase"].as_str().unwrap_or("?");
        let plume = if phase == "powered" {
            "          /\\/\\       EXAUSTÃO"
        } else if phase == "ready" {
            "         ======      BASE"
        } else {
            "           ||        MOTOR INATIVO"
        };
        let mut lines = vec![
            "            /\\".into(),
            "           /  \\".into(),
            "          /____\\      CARGA DE PESQUISA".into(),
            "          | <> |".into(),
            "          |----|      SEPARAÇÃO".into(),
            "          | || |      TANQUE".into(),
            "         /|____|\\".into(),
            "        /_/ || \\_\\    ALETAS".into(),
            plume.into(),
            format!(
                "ALT {} m · VEL {} m/s · FASE {phase}",
                format_number(&o["altitude_m"]),
                format_number(&o["velocity_m_s"])
            ),
        ];
        if o["secondary_altitude_m"].is_number() {
            lines.push(format!(
                "A {} m · B {} m · diferença {} m · META {} m",
                format_number(&o["primary_altitude_m"]),
                format_number(&o["secondary_altitude_m"]),
                format_number(&o["sensor_disagreement_m"]),
                format_number(&o["target_altitude_m"])
            ));
        } else {
            lines.push(format!(
                "META {} m · ALTITUDE ±{} m · tecnologia nível {}",
                format_number(&o["target_altitude_m"]),
                format_number(&o["altitude_uncertainty_m"]),
                format_number(&o["tech_level"])
            ));
        }
        lines
    } else {
        let mut lines = vec![
            "       QUADRO DE SINAIS".into(),
            "  ┌────────────────────────────┐".into(),
        ];
        if let Some(contacts) = o["contacts"].as_array() {
            for c in contacts {
                lines.push(format!(
                    "  │ {:<6} {:<9} {:>2}/{:<2} │",
                    c["id"].as_str().unwrap_or("?"),
                    c["status"].as_str().unwrap_or("?"),
                    format_number(&c["work"]),
                    format_number(&c["work_required"])
                ));
            }
        }
        lines.extend([
            "  └────────────────────────────┘".into(),
            format!(
                "EQUIPES DISPONÍVEIS: {}",
                format_number(&o["available_teams"])
            ),
            format!(
                "PRAZOS ESTIMADOS: ±{} s · tecnologia nível {}",
                format_number(&o["deadline_uncertainty_s"]),
                format_number(&o["tech_level"])
            ),
        ]);
        if o["network_monitoring"] == true {
            lines.push("REDE ATIVA: alerta automático perto do prazo".into());
        }
        lines
    }
}

fn research_lines(profile: Option<&Value>) -> Vec<String> {
    let Some(profile) = profile else {
        return vec!["Perfil de pesquisa indisponível".into()];
    };
    let filter = profile["filter_unlocked"] == true;
    let network = profile["network_unlocked"] == true;
    let mut lines = vec![
        "      LABORATÓRIO DE COMPUTAÇÃO".into(),
        String::new(),
        format!("PONTOS DISPONÍVEIS: {}", format_number(&profile["points"])),
        format!("NÍVEL TECNOLÓGICO: {}", format_number(&profile["tier"])),
        String::new(),
        format!(
            "[{}] BANCADA DE FILTRAGEM · altitude e prazo mais precisos",
            if filter { "X" } else { " " }
        ),
        format!(
            "[{}] REDE DE SENSORES · dois canais e avisos de prazo",
            if network { "X" } else { " " }
        ),
        String::new(),
    ];
    if profile["next_unlock"].is_object() {
        lines.push(format!(
            "PRÓXIMO: {} · {} ponto(s)",
            profile["next_unlock"]["title"].as_str().unwrap_or("?"),
            format_number(&profile["next_unlock"]["cost"])
        ));
        lines.push(format!(
            "Comando: research {}",
            profile["next_unlock"]["id"].as_str().unwrap_or("?")
        ));
    } else {
        lines.push("PRÓXIMAS ETAPAS: IA e supercomputação em desenvolvimento".into());
    }
    lines.push("Desbloqueios afetam somente novas missões.".into());
    lines
}

fn render_lines(
    frame: &mut ratatui::Frame,
    area: Rect,
    title: &str,
    lines: Vec<String>,
    color: Color,
) {
    let text = Text::from(lines.into_iter().map(Line::from).collect::<Vec<_>>());
    frame.render_widget(
        Paragraph::new(text)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(title)
                    .border_style(Style::default().fg(color)),
            )
            .wrap(Wrap { trim: false }),
        area,
    );
}

fn draw(frame: &mut ratatui::Frame, app: &App) {
    let area = frame.area();
    let color = app.palette.color();
    let tiny = area.width < 80 || area.height < 24;
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2),
            Constraint::Min(5),
            Constraint::Length(3),
            Constraint::Length(2),
        ])
        .split(area);
    let mode = app
        .mode
        .as_deref()
        .map(mode_title)
        .unwrap_or("SELEÇÃO DE MODO");
    let header = Line::from(vec![
        Span::styled(
            " TERMINAL LAUNCH SIM ",
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
        Span::raw(format!("│ {mode} │ t={} s │ seq {}", app.time_s(), app.seq)),
    ]);
    frame.render_widget(Paragraph::new(header), rows[0]);

    if let Some(snapshot) = &app.snapshot {
        let o = &snapshot["observation"];
        if tiny {
            let lines = match app.panel {
                Panel::Mission => mission_lines(o),
                Panel::Telemetry => telemetry_lines(o),
                Panel::Log => {
                    if app.logs.is_empty() {
                        vec!["Nenhum evento ainda".into()]
                    } else {
                        app.logs.iter().rev().cloned().collect()
                    }
                }
                Panel::Research => research_lines(app.profile.as_ref()),
            };
            render_lines(
                frame,
                rows[1],
                &format!("{} · TAB troca painel", app.panel.name()),
                lines,
                color,
            );
        } else {
            let sections = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Percentage(52), Constraint::Percentage(48)])
                .split(rows[1]);
            let research = matches!(app.panel, Panel::Research);
            render_lines(
                frame,
                sections[0],
                if research {
                    "PESQUISA"
                } else {
                    "VISÃO DA MISSÃO"
                },
                if research {
                    research_lines(app.profile.as_ref())
                } else {
                    mission_lines(o)
                },
                color,
            );
            let columns = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
                .split(sections[1]);
            render_lines(
                frame,
                columns[0],
                "TELEMETRIA · VALORES OBSERVADOS",
                telemetry_lines(o),
                color,
            );
            let logs = if app.logs.is_empty() {
                vec!["Aguardando eventos".into()]
            } else {
                app.logs.iter().rev().cloned().collect()
            };
            render_lines(frame, columns[1], "ALERTAS / LOG", logs, color);
        }
    } else {
        render_lines(
            frame,
            rows[1],
            if matches!(app.panel, Panel::Research) {
                "PESQUISA"
            } else {
                "INICIAR"
            },
            if matches!(app.panel, Panel::Research) {
                research_lines(app.profile.as_ref())
            } else {
                vec![
                    "".into(),
                    "  [1] PROGRAMA ESPACIAL    Foguete de pesquisa".into(),
                    "  [2] CENTRAL FICTÍCIA     Coordenação de sinais".into(),
                    "".into(),
                    "  Enter envia comandos; F1 abre ajuda; Ctrl+C sai.".into(),
                ]
            },
            color,
        );
    }

    let input = Paragraph::new(format!("> {}", app.input)).block(
        Block::default()
            .borders(Borders::ALL)
            .title("COMANDO / CALCULADORA")
            .border_style(Style::default().fg(color)),
    );
    frame.render_widget(input, rows[2]);
    frame.render_widget(
        Paragraph::new(format!(
            " {} │ F1 ajuda · F2 paleta {} · Tab painel · Ctrl+C sair",
            app.status,
            app.palette.name()
        )),
        rows[3],
    );
    let cursor_x = rows[2]
        .x
        .saturating_add(3)
        .saturating_add(app.input.chars().count() as u16);
    if cursor_x < rows[2].right().saturating_sub(1) {
        frame.set_cursor_position((cursor_x, rows[2].y + 1));
    }

    if app.help {
        let width = area.width.saturating_sub(4).min(72);
        let height = area.height.saturating_sub(4).min(18);
        let pop = Rect::new(
            area.x + (area.width - width) / 2,
            area.y + (area.height - height) / 2,
            width,
            height,
        );
        frame.render_widget(Clear, pop);
        let commands = if app.mode.as_deref() == Some("central") {
            "assign orion | assign vega | recall orion | recall vega | wait N"
        } else {
            "check | launch | abort | wait N"
        };
        let help = vec![
            "SELEÇÃO E CONTROLES".into(),
            "  1 espacial  ·  2 central (tela inicial)".into(),
            "  F1 ajuda  ·  F2 paleta  ·  Tab/F3 painel".into(),
            "  Esc limpa entrada  ·  Ctrl+C sai".into(),
            "".into(),
            format!("COMANDOS: {commands}"),
            "  wait N: avança 1 a 500 segundos simulados".into(),
            "  space [SEMENTE] | central [SEMENTE]".into(),
            "  snapshot: sincroniza instrumentos".into(),
            "  tech: pesquisa e pontos disponíveis".into(),
            "  research filter: compra a bancada".into(),
            "  research network: compra a rede de sensores".into(),
            "  calc speed DISTÂNCIA_M TEMPO_S".into(),
            "  calc eta TRABALHO_RESTANTE EQUIPES".into(),
            "".into(),
            "Leituras podem ter incerteza. A calculadora indica o modelo.".into(),
            "Enter ou Esc fecha esta janela.".into(),
        ];
        render_lines(frame, pop, "AJUDA", help, color);
    }
}

fn run() -> Result<(), String> {
    let engine = EngineClient::start()?;
    let mut app = App::new(engine);
    let mut terminal = ratatui::init();
    let result: io::Result<()> = (|| {
        while !app.quit {
            terminal.draw(|frame| draw(frame, &app))?;
            if let Event::Key(key) = event::read()? {
                app.on_key(key);
            }
        }
        Ok(())
    })();
    ratatui::restore();
    result.map_err(|e| e.to_string())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("terminal-launch-sim: {e}");
        std::process::exit(1);
    }
}
