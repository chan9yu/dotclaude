# MCP 서버 설정

선호하는 MCP 서버 구성 목록. `~/.claude.json`의 `mcpServers`에 등록하여 사용한다.

## 전역 설정

### Redmine

> 출처: [yonaka15/mcp-redmine](https://github.com/yonaka15/mcp-redmine)

프로젝트 관리 도구 연동. 이슈 조회/생성/업데이트 등을 지원한다.

**사용 프로세스**: env에 Redmine URL과 API 키를 설정하면 바로 사용 가능.

```json
{
  "redmine": {
    "type": "stdio",
    "command": "uvx",
    "args": ["--refresh-package", "mcp-redmine", "mcp-redmine"],
    "env": {
      "REDMINE_URL": "<REDMINE_URL>",
      "REDMINE_API_KEY": "<REDMINE_API_KEY>"
    }
  }
}
```

### Serena

> 출처: [oraios/serena](https://github.com/oraios/serena)

시맨틱 코드 분석 도구. 심볼 탐색, 리팩토링, 참조 검색 등 LSP 기반 코드 조작을 지원한다.

**사용 프로세스**: `uvx`로 자동 설치되며, `--project-from-cwd` 옵션으로 현재 디렉토리의 프로젝트를 자동 감지한다.

```json
{
  "serena": {
    "type": "stdio",
    "command": "uvx",
    "args": [
      "--from",
      "git+https://github.com/oraios/serena",
      "serena",
      "start-mcp-server",
      "--context=claude-code",
      "--project-from-cwd",
      "--open-web-dashboard=false"
    ]
  }
}
```

### GitLab

> 출처: [@zereight/mcp-gitlab](https://github.com/zereight/mcp-gitlab)

GitLab API 연동. MR 조회, 이슈 관리, 파이프라인 확인 등을 지원한다.

**사용 프로세스**: env에 Personal Access Token과 GitLab API URL을 설정하면 바로 사용 가능.

```json
{
  "gitlab": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@zereight/mcp-gitlab"],
    "env": {
      "GITLAB_PERSONAL_ACCESS_TOKEN": "<GITLAB_TOKEN>",
      "GITLAB_API_URL": "<GITLAB_API_URL>"
    }
  }
}
```

### Figma

> 출처: Figma 공식 제공 ([Figma MCP Server](https://github.com/nichochar/figma-mcp))

Figma 디자인 파일 연동. 디자인 스펙 조회 및 컴포넌트 정보를 가져올 수 있다.

**사용 프로세스**: HTTP 타입으로 설정 후, 첫 사용 시 브라우저에서 OAuth 인증을 진행하면 자동 연동된다.

```json
{
  "figma": {
    "type": "http",
    "url": "https://mcp.figma.com/mcp"
  }
}
```

### Context7

> 출처: [upstash/context7](https://github.com/upstash/context7)

라이브러리 문서 검색 도구. 최신 문서와 코드 예제를 실시간으로 조회할 수 있다.

**사용 프로세스**: 설정만 하면 바로 사용 가능. 별도의 인증이나 API 키가 필요 없다.

```json
{
  "context7": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp@latest"]
  }
}
```
