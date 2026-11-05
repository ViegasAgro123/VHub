# AOTR Hub

Attack on Titan Revolution — script para executor.

## Uso

Cola isto no executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ViegasAgro123/VHub/main/loader.lua"))()
```

Ou, apontando direto para o script (sem stub, sem auto-update):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ViegasAgro123/VHub/main/aotr/main.lua"))()
```

**RightControl** abre e fecha a interface.

## Arquivos

| Arquivo | O que é |
|---|---|
| `loader.lua` | Stub curto. Busca `aotr/main.lua` e executa. É o que você cola. |
| `aotr/main.lua` | O script completo, auto-contido. |
| `diagnose/extract.lua` | Captura chunks de outros scripts (rodar antes do alvo). |
| `diagnose/recorder.lua` | Grava remotes, GUI e estado do alvo em arquivo. |

## Atualização

O stub tem um cache-buster por hora. Correções publicadas aqui chegam no
próximo `loadstring`, sem recolar nada.

---

Gerado por `build/publish.mjs`. Não edite estes arquivos à mão — edite
`src/` no projeto e republique.
