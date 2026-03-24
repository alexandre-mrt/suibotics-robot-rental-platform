/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_PACKAGE_ID: string;
  readonly VITE_REGISTRY_OBJECT_ID: string;
  readonly VITE_ESCROW_OBJECT_ID: string;
  readonly VITE_COMMAND_AUTH_OBJECT_ID: string;
  readonly VITE_FAUCET_OBJECT_ID: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
