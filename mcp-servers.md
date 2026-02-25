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

### Serena

> 출처: [oraios/serena](https://github.com/oraios/serena)

시맨틱 코드 분석 및 편집 도구. 심볼 단위로 코드를 탐색하고, 참조 추적·리네이밍·심볼 교체 등 구조적 코드 편집을 지원한다.

**사용 프로세스**: 별도 env 없이 설치만 하면 사용 가능. `--project-from-cwd` 옵션으로 현재 디렉토리의 프로젝트를 자동 인식한다.

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

### Figma

> 출처: [Figma 공식 MCP](https://mcp.figma.com)

Figma 디자인 연동. 디자인 컨텍스트 추출, 스크린샷 조회, Code Connect 매핑, FigJam 다이어그램 생성 등을 지원한다.

**사용 프로세스**: HTTP 타입으로 Figma 공식 MCP 엔드포인트에 연결. 최초 사용 시 OAuth 인증이 필요하다.

```json
{
	"figma": {
		"type": "http",
		"url": "https://mcp.figma.com/mcp"
	}
}
```

### Sequential Thinking

> 출처: [@modelcontextprotocol/server-sequential-thinking](https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking)

단계적 사고 프레임워크. 복잡한 문제를 번호가 매겨진 단계로 분해하여 분석하며, 이전 단계의 수정·분기가 가능하다. Claude가 내부적으로 활용하는 도구로, 사용자가 직접 호출하지 않는다.

**사용 프로세스**: 별도 설정 없이 등록만 하면 사용 가능.

```json
{
	"sequential-thinking": {
		"command": "npx",
		"args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
	}
}
```
