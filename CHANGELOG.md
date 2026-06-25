# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added

- **Fundação da v1** (reescrita greenfield, `add-ruby-foundation`):
  - gem `nfe-io` 1.0.0 com piso **Ruby 3.2+** e **zero dependências de runtime** (apenas stdlib).
  - namespace `Nfe`, entrypoint `Nfe::Client.new(api_key:)` estilo Stripe com 17 acessores de recurso lazy.
  - `Nfe::Configuration` como fonte única do mapa multi-base-URL (`base_url_for`).
  - `Nfe::FlowStatus.terminal?` para o futuro contrato 202 (Pending/Issued).
  - tooling: RSpec + SimpleCov (gate ≥ 80%), RuboCop (+ rubocop-rspec), RBS, Steep.
  - CI (GitHub Actions) em matrix Ruby 3.2 / 3.3 / 3.4.

### Changed

- Entrypoint migrado da API global (`Nfe.api_key`) para `Nfe::Client.new` — ver `MIGRATION.md`.

### Removed

- Dependência de runtime `rest-client`.
- API legada da série `0.x` (preservada no branch `0.x-legacy`).

## [0.3.2]

- Última versão da série `0.x` (legada, baseada em `rest-client`). Congelada, sem manutenção.

[Unreleased]: https://github.com/nfe/client-ruby/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/nfe/client-ruby/releases/tag/v0.3.2
