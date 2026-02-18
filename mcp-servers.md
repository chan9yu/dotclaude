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
