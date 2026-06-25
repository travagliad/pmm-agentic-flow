import fs from "node:fs";
import yaml from "js-yaml";
import { z } from "zod";

const repoSchema = z.object({
  repository: z.string(),
  clone_url: z.string().url(),
  default_branch: z.string().default("main"),
});

const infrastructureSchema = z.object({
  linode: z.object({
    control_plane_type: z.string().default("g6-standard-4"),
    worker_type: z.string().default("g6-standard-8"),
    region: z.string().default("eu-central"),
  }),
});

const stackConfigSchema = z.object({
  infrastructure: infrastructureSchema.default({
    linode: {
      control_plane_type: "g6-standard-4",
      worker_type: "g6-standard-8",
      region: "eu-central",
    },
  }),
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
    controller: z.string().default("agents/microagents/loop-controller.md"),
    loop_controller: z.string().optional(),
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

export type StackConfig = z.infer<typeof stackConfigSchema>;
/** @deprecated use StackConfig */
export type LoopConfig = StackConfig;
export type JiraWorkflowConfig = z.infer<typeof jiraWorkflowSchema>;

export type Env = {
  orchestratorPort: number;
  orchestratorApiKey: string;
  agentCanvasBaseUrl: string;
  agentCanvasPublicUrl: string;
  agentCanvasApiKey: string;
  githubToken: string;
  sandboxTtlHours: number;
  maxAgentRetries: number;
  maxBuildRetries: number;
  stackConfigPath: string;
  jiraWorkflowPath: string;
  jiraBaseUrl?: string;
  jiraEmail?: string;
  jiraApiToken?: string;
  jiraWebhookSecret?: string;
  dataDir: string;
  linodeToken?: string;
  workerRootPassword?: string;
};

export function loadEnv(): Env {
  const required = (key: string) => {
    const value = process.env[key];
    if (!value) throw new Error(`Missing required env var: ${key}`);
    return value;
  };

  const apiKey = process.env.AGENT_CANVAS_API_KEY ?? process.env.LOCAL_BACKEND_API_KEY;
  if (!apiKey) throw new Error("Missing AGENT_CANVAS_API_KEY");

  return {
    orchestratorPort: Number(process.env.ORCHESTRATOR_PORT ?? 8080),
    orchestratorApiKey: required("ORCHESTRATOR_API_KEY"),
    agentCanvasBaseUrl: process.env.AGENT_CANVAS_BASE_URL ?? "http://agent-canvas:8000",
    agentCanvasPublicUrl: process.env.AGENT_CANVAS_PUBLIC_URL ?? "https://127.0.0.1",
    agentCanvasApiKey: apiKey,
    githubToken: required("GITHUB_TOKEN"),
    sandboxTtlHours: Number(process.env.SANDBOX_TTL_HOURS ?? 72),
    maxAgentRetries: Number(process.env.MAX_AGENT_RETRIES ?? 2),
    maxBuildRetries: Number(process.env.MAX_BUILD_RETRIES ?? 5),
    stackConfigPath: process.env.STACK_CONFIG_PATH ?? "/config/stack.yaml",
    jiraWorkflowPath: process.env.JIRA_WORKFLOW_PATH ?? "/config/jira-workflow.yaml",
    jiraBaseUrl: process.env.JIRA_BASE_URL,
    jiraEmail: process.env.JIRA_EMAIL,
    jiraApiToken: process.env.JIRA_API_TOKEN,
    jiraWebhookSecret: process.env.JIRA_WEBHOOK_SECRET,
    dataDir: process.env.DATA_DIR ?? "/data",
    linodeToken: process.env.LINODE_TOKEN,
    workerRootPassword: process.env.WORKER_ROOT_PASSWORD,
  };
}

export function loadStackConfig(path: string): StackConfig {
  const raw = fs.readFileSync(path, "utf8");
  const parsed = stackConfigSchema.parse(yaml.load(raw));
  if (!parsed.agents.controller && parsed.agents.loop_controller) {
    parsed.agents.controller = parsed.agents.loop_controller;
  }
  return parsed;
}

/** @deprecated use loadStackConfig */
export const loadLoopConfig = loadStackConfig;

export function loadJiraWorkflow(path: string): JiraWorkflowConfig {
  const raw = fs.readFileSync(path, "utf8");
  return jiraWorkflowSchema.parse(yaml.load(raw));
}

export function linodeWorkerSettings(stack: StackConfig) {
  return stack.infrastructure.linode;
}
