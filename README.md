## Vulnerable Uniswap V4 Hooks

EmptyHook is just a template for deploying test hooks.

1. [hookCallerModifier](https://github.com/Entropy1110/vuln-hooks/tree/main/hookCallerModifier) : Access control modifiers are not implemented in Hook functions.
2. [hookDoubleInit](https://github.com/Entropy1110/vuln-hooks/tree/main/hookDoubleInit) : One Hook is initialized in more than one Pool, while initializing the Hook's storage variables.
3. [hookUpgradable](https://github.com/Entropy1110/vuln-hooks/tree/main/hookUpgradable) : Hook can be upgraded to malicious hook. ex) Tokens locked in the hook contract, unable to removeLiquidity, gas griefing, etc.
4. [hookMalicious](https://github.com/Entropy1110/vuln-hooks/tree/main/hookUpgradable) : Hook that can steal approved token from user.
5. WIP
