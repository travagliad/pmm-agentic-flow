import fs from "node:fs";
import yaml from "js-yaml";
import { z } from "zod";

const repoSchema = z.object({
  repository: z.string(),
  clone_url: z.string().url(),
  default_branch: z.string().default("main"),
});

const loopConfigSchema = z.object({
  dev: repoSchema.extend({
    alt_repositories: z
      .array(z.object({ name: z.string(), repository: z.string(), clone_url: z.string().url() }))
      .optional(),
    build_command: z.string().default("make build"),
  }),
  qa: repoSchema.extend({
    editable_paths: z.array(z.string()),
    legacy_paths_readonly: z.array(z.string()).optional(),
    default_suite: z.string(),
    suites: z.record(
      z.object({
        runner: z.string(),
        workflow: z.string().optional(),
      }),
    ),
  }),
  environment: z.object({
    default_mode: z.enum(["pmm-framework", "jenkins-staging", "external"]),
    pmm_framework: z
      .object({
        script: z.string(),
        network: z.string(),
        docs: z.array(z.string()).optional(),
      })
      .optional(),
    jenkins_staging: z
      .object({
        job: z.string(),
        pipelines_repo: z.string(),
        submodules_repo: z.string(),
      })
      .optional(),
    external: z.object({ env_var: z.string() }).optional(),
  }),
  build_artifacts: z
    .object({
      submodules_repo: z.string(),
      resolve_from: z.string(),
    })
    .optional(),
  openspec: z.object({
    repository: z.string(),
    changes_dir: z.string(),
    require_spec_approval: z.boolean().default(true),
  }),
  agents: z.object({
    loop_controller: z.string().default("agents/microagents/loop-controller.md"),
    dev: z.object({ microagent: z.string(), max_iterations: z.number().default(80) }),
    qa: z.object({ microagent: z.string(), max_iterations: z.number().default(40) }),
  }),
  lifecycle: z.object({
    trigger: z.enum(["manual", "jira_webhook", "both"]).default("both"),
    phases: z.array(z.string()),
  }),
  sandbox: z.object({
    ttl_hours: z.number().default(72),
    keep_warm_until: z.string().default("ready_for_merge"),
    workspace_layout: z.array(z.object({ path: z.string(), repo: z.string() })).optional(),
    expose: z.array(z.string()).default(["vscode", "ssh", "preview"]),
    setup_script: z.string().default("sandbox/setup-pmm-workspace.sh"),
  }),
});

export const jiraWorkflowSchema = z.object({
  jira: z.object({
    project_key: z.string(),
    statuses: z.object({
      ready_for_refinement: z.string(),
      ready_for_work: z.string(),
      in_progress: z.string(),
      in_review: z.string(),
      in_qa: z.string(),
      ready_for_merge: z.string(),
    }),
    comments: z.object({
      spec_pr: z.string(),
      dev_pr: z.string(),
      qa_pr: z.string(),
      test_instance: z.string(),
      ssh_access: z.string(),
      conversation: z.string(),
      access_bundle: z.string().optional(),
    }),
  }),
  commands: z.object({
    ready_for_refinement: z.string(),
    in_progress: z.string(),
    in_qa: z.string(),
    ready_for_merge: z.string(),
    on_merge: z.string(),
  }),
  access_links: z.object({
    post_on_in_progress: z.boolean().default(true),
    refresh_on_in_review: z.boolean().default(true),
    include_ssh: z.boolean().default(true),
  }),
  openspec: z
    .object({
      explore: z.object({ enabled: z.boolean(), automated: z.boolean() }).optional(),
      archive: z.object({ automated_on_merge: z.boolean() }).optional(),
    })
    .optional(),
});

export type LoopConfig = z.infer<typeof loopConfigSchema>;
export type JiraWorkflowConfig = z.infer<typeof jiraWorkflowSchema>;

export type Env = {
  orchestratorPort: number;
  orchestratorApiKey: string;
  openhandsBaseUrl: string;
  openhandsPublicUrl: string;
  openhandsApiKey: string;
  githubToken: string;
  sandboxTtlHours: number;
  maxAgentRetries: number;
  maxBuildRetries: number;
  loopConfigPath: string;
  jiraWorkflowPath: string;
  jiraBaseUrl?: string;
  jiraEmail?: string;
  jiraApiToken?: string;
  jiraWebhookSecret?: string;
  dataDir: string;
};

export function loadEnv(): Env {
  const required = (key: string) => {
    const value = process.env[key];
    if (!value) throw new Error(`Missing required env var: ${key}`);
    return value;
  };

  return {
    orchestratorPort: Number(process.env.ORCHESTRATOR_PORT ?? 8080),
    orchestratorApiKey: required("ORCHESTRATOR_API_KEY"),
    openhandsBaseUrl: process.env.OPENHANDS_BASE_URL ?? "http://127.0.0.1:3000",
    openhandsPublicUrl: process.env.OPENHANDS_PUBLIC_URL ?? process.env.LOOP_DOMAIN
      ? `https://${process.env.LOOP_DOMAIN}`
      : "http://127.0.0.1:3000",
    openhandsApiKey: required("OPENHANDS_API_KEY"),
    githubToken: required("GITHUB_TOKEN"),
    sandboxTtlHours: Number(process.env.SANDBOX_TTL_HOURS ?? 72),
    maxAgentRetries: Number(process.env.MAX_AGENT_RETRIES ?? 2),
    maxBuildRetries: Number(process.env.MAX_BUILD_RETRIES ?? 5),
    loopConfigPath: process.env.LOOP_CONFIG_PATH ?? "/config/loop.yaml",
    jiraWorkflowPath: process.env.JIRA_WORKFLOW_PATH ?? "/config/jira-workflow.yaml",
    jiraBaseUrl: process.env.JIRA_BASE_URL,
    jiraEmail: process.env.JIRA_EMAIL,
    jiraApiToken: process.env.JIRA_API_TOKEN,
    jiraWebhookSecret: process.env.JIRA_WEBHOOK_SECRET,
    dataDir: process.env.DATA_DIR ?? "/data",
  };
}

export function loadLoopConfig(path: string): LoopConfig {
  const raw = fs.readFileSync(path, "utf8");
  return loopConfigSchema.parse(yaml.load(raw));
}

export function loadJiraWorkflow(path: string): JiraWorkflowConfig {
  const raw = fs.readFileSync(path, "utf8");
  return jiraWorkflowSchema.parse(yaml.load(raw));
}
