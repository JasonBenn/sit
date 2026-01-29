/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as beliefs from "../beliefs.js";
import type * as meditationSessions from "../meditationSessions.js";
import type * as promptResponses from "../promptResponses.js";
import type * as promptSettings from "../promptSettings.js";
import type * as timerPresets from "../timerPresets.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  beliefs: typeof beliefs;
  meditationSessions: typeof meditationSessions;
  promptResponses: typeof promptResponses;
  promptSettings: typeof promptSettings;
  timerPresets: typeof timerPresets;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
