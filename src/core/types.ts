// src/core/types.ts — 类型定义

export interface SkillMeta {
  name: string;
  description: string;
  triggers: string[];
  args: SkillArg[];
  steps: string[]; // step 文件名列表
}

export interface SkillArg {
  name: string;
  type: 'string' | 'number' | 'boolean';
  required: boolean;
  default?: string | number | boolean;
  description?: string;
}

export interface Skill {
  name: string;
  dir: string;
  meta: SkillMeta;
  mainPath: string;
  stepPaths: string[];
}

export interface RunContext {
  skill: Skill;
  args: Record<string, string | number | boolean>;
  skillDir: string;
}

export interface CliConfig {
  skillsDir: string;
  debug: boolean;
}
