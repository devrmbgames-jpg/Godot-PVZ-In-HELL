extends Component
## Живая связь носителя испытания с участвующим игроком.
## ChallengeService.arm связывает target actor; cleanup снимает связь, не удаляя игрока.
## Потеря actor/связи отменяет сеанс через O_ChallengeLifecycle/ChallengeService.
class_name R_ChallengeActor
