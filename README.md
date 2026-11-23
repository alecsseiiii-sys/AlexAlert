# AlexAlert

Addon independente para WoW Forever (`Interface 16001`). As configurações abrem com `/alexa`.

## Alertas

- **Raro (azul)** é o padrão e inclui raros, épicos e lendários.
- **Épico (roxo)** inclui épicos e lendários.
- **Lendário (laranja)** alerta apenas lendários.
- O som pode ser escolhido entre Subida de nível, Alerta de raide, Pronto e Sino. Use **Testar som** para ouvir.
- O alerta é disparado ao receber o item; funciona junto com auto loot e addons de loot rápido.

## Prévia de drops no mouseover

O cliente do WoW não fornece aos addons a tabela completa de loot de qualquer NPC. O AlexAlert aprende os itens vistos em cada janela de loot e guarda essa lista por personagem; assim a prévia melhora conforme você encontra itens. Para incluir dados de uma base externa, adicione IDs confirmados em `Data.lua`, no formato `AlexAlertLoot[ID_DO_NPC] = { ID_DO_ITEM, ... }`. O tooltip combina as duas fontes e mostra apenas itens que atendem à raridade mínima escolhida, ordenados da maior raridade para a menor.

O Wowhead pode servir como fonte para gerar/preencher esse arquivo local. O addon não consulta o site dentro do jogo; o Wowhead Client/Looter coleta observações de jogadores e as envia ao site, então as tabelas são agregadas e podem não refletir alterações específicas do servidor Forever. [Página do Wowhead Client](https://www.wowhead.com/client) · [Como o Wowhead reúne dados de loot](https://www.wowhead.com/news/help-contribute-to-the-wowhead-database-wowhead-client-looter-highlight-342952).

O GUID do NPC deve estar disponível como `Creature` ou `Vehicle`. A qualidade dos itens precisa estar carregada pelo cliente para aparecer na prévia.

## Instalação

Copie a pasta `AlexAlert` para `Interface/AddOns` e reinicie o jogo ou use `/reload`.
