use serde_json::{Value, json};
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::time::Duration;

pub struct EngineClient {
    child: Child,
    input: ChildStdin,
    output: Receiver<Result<String, String>>,
    next_request: u64,
}

impl EngineClient {
    pub fn start() -> Result<Self, String> {
        let engine_dir = std::env::var_os("TLS_ENGINE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../engine"));

        let deps = Command::new("mix")
            .arg("deps.get")
            .current_dir(&engine_dir)
            .output()
            .map_err(|e| format!("Não foi possível executar mix deps.get: {e}"))?;
        if !deps.status.success() {
            return Err(format!(
                "Falha ao obter dependências do motor:\n{}",
                String::from_utf8_lossy(&deps.stderr)
            ));
        }

        let compiled = Command::new("mix")
            .arg("compile")
            .arg("--quiet")
            .current_dir(&engine_dir)
            .output()
            .map_err(|e| format!("Não foi possível executar mix compile: {e}"))?;
        if !compiled.status.success() {
            return Err(format!(
                "Falha ao compilar motor:\n{}",
                String::from_utf8_lossy(&compiled.stderr)
            ));
        }

        let mut child = Command::new("mix")
            .args([
                "run",
                "--no-compile",
                "-e",
                "Engine.Protocol.main(System.argv())",
                "--",
            ])
            .current_dir(engine_dir)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| format!("Não foi possível iniciar o motor: {e}"))?;
        let input = child.stdin.take().ok_or("stdin do motor indisponível")?;
        let stdout = child.stdout.take().ok_or("stdout do motor indisponível")?;
        let (sender, output) = mpsc::channel();
        std::thread::spawn(move || {
            let mut reader = BufReader::new(stdout);
            loop {
                let mut line = String::new();
                match reader.read_line(&mut line) {
                    Ok(0) => {
                        let _ = sender.send(Err("Motor encerrou a conexão".into()));
                        break;
                    }
                    Ok(_) => {
                        if sender.send(Ok(line)).is_err() {
                            break;
                        }
                    }
                    Err(e) => {
                        let _ = sender.send(Err(format!("Falha de leitura do motor: {e}")));
                        break;
                    }
                }
            }
        });
        Ok(Self {
            child,
            input,
            output,
            next_request: 1,
        })
    }

    pub fn request(
        &mut self,
        kind: &str,
        run_id: Option<&str>,
        seq: u64,
        payload: Value,
    ) -> Result<Value, String> {
        let request_id = format!("tui-{}", self.next_request);
        self.next_request += 1;
        let message = json!({
            "protocol_version": 1,
            "request_id": request_id,
            "run_id": run_id,
            "seq": seq,
            "type": kind,
            "payload": payload,
        });
        writeln!(self.input, "{message}")
            .and_then(|_| self.input.flush())
            .map_err(|e| format!("Falha ao enviar comando: {e}"))?;
        let timeout = if kind == "run.create" || kind == "catalog.list" {
            Duration::from_secs(20)
        } else {
            Duration::from_secs(5)
        };
        let line = self
            .output
            .recv_timeout(timeout)
            .map_err(|e| format!("Motor não respondeu a tempo: {e}"))??;
        if line.len() > 1_048_576 {
            return Err("Resposta do motor excede 1 MiB".into());
        }
        decode_response(&line, &request_id)
    }
}

fn decode_response(line: &str, request_id: &str) -> Result<Value, String> {
    let response: Value =
        serde_json::from_str(line).map_err(|e| format!("Resposta JSON inválida do motor: {e}"))?;
    if response["protocol_version"] != 1
        || response["type"] != "response"
        || response["request_id"] != request_id
    {
        return Err("Resposta do motor não corresponde à requisição".into());
    }
    let reply = &response["payload"];
    if reply["ok"] == true {
        if reply["data"].is_object() {
            Ok(reply["data"].clone())
        } else {
            Err("Resposta de sucesso sem dados".into())
        }
    } else if reply["ok"] == false {
        let code = reply["error"]["code"].as_str().unwrap_or("engine_error");
        let message = reply["error"]["message"]
            .as_str()
            .unwrap_or("Comando rejeitado");
        Err(format!("{code}: {message}"))
    } else {
        Err("Resposta sem estado ok".into())
    }
}

#[cfg(test)]
mod tests {
    use super::decode_response;
    use serde_json::json;

    #[test]
    fn rejects_response_for_another_request() {
        let response = json!({"protocol_version":1,"request_id":"old","run_id":"run-1","seq":1,"type":"response","payload":{"ok":true,"data":{"snapshot":{}}}});
        assert!(decode_response(&response.to_string(), "current").is_err());
    }

    #[test]
    fn returns_backend_error_code_and_message() {
        let response = json!({"protocol_version":1,"request_id":"current","run_id":"run-1","seq":1,"type":"response","payload":{"ok":false,"error":{"code":"check_required","message":"Check first"}}});
        assert_eq!(
            decode_response(&response.to_string(), "current"),
            Err("check_required: Check first".into())
        );
    }
}

impl Drop for EngineClient {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}
