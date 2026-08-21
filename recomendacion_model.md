
Rol	Demanda	Modelo OpenCode Go recomendado	Justificación
spec_partner	deep	Claude Opus (Agent)	Razonamiento profundo, debate de producto, pushback creativo
gherkin_author	standard	GLM‑5.2	Destilación estructurada, excelente comprensión de especificaciones y generación Gherkin
tdd_craftsman	standard	DeepSeek V4 Pro	Codificación TDD, iteración rápida, cumplimiento estricto de las Tres Leyes
judge	deep	Claude Opus (Agent)	Revisión exhaustiva de cobertura, disciplina TDD y calidad; “el review es el juego entero”
mutation_tester	cheap	DeepSeek V4 Flash	Ejecución de mutación; apenas necesita LLM, solo orquestación ligera
harness_bootstrap	cheap	DeepSeek V4 Flash	Detección de stack, generación de configuración inicial; tarea casi de script
cierre	cheap	DeepSeek V4 Flash (opcional)	Flip de estado y movimiento de bitácora; lógica simple, sin agente propio
Explore	cheap	DeepSeek V4 Flash	Barrido de lectura y análisis superficial; sin generación compleja
