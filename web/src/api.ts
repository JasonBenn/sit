// REST API client for Sit backend

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8005';

// Types
export interface PromptResponse {
  id: string;
  responded_at: string;
  initial_answer: string;        // "in_view" | "not_in_view"
  gate_exercise_result: string | null;  // "worked" | "didnt_work"
  final_state: string;           // "reflection_complete" | "voice_note_recorded"
  voice_note_s3_url: string | null;
  voice_note_duration_seconds: number | null;
  transcription: string | null;
  transcription_status: string | null;
  created_at: string;
}

// Generic fetch wrapper
async function fetchAPI<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });

  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }

  return response.json();
}

// Prompt Responses API
export const promptResponsesAPI = {
  list: (limit?: number) =>
    fetchAPI<PromptResponse[]>(`/api/prompt-responses${limit ? `?limit=${limit}` : ''}`),
};

// Health check
export const healthAPI = {
  check: () => fetchAPI<{ status: string }>('/health'),
};
