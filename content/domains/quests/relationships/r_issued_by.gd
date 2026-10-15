extends Component
## Связывает живое задание с выдавшим его торговцем.
## target — issuer Entity; RefusalQuestService создаёт binding и снимает его при resolve.
## Permanent issuer_key/исход остаются в RefusalQuestRecord и не выводятся из живой ссылки.
class_name R_IssuedBy
