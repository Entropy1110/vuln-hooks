const fs = require('fs');
const parser = require('solidity-parser-antlr');

const filePath = process.argv[2];

if (!filePath) {
    console.error('Usage: node check_hooks.js <SolidityFile.sol>');
    process.exit(1);
}

let content;
try {
    content = fs.readFileSync(filePath, 'utf8');
} catch (err) {
    console.error(`Error reading file '${filePath}': ${err.message}`);
    process.exit(1);
}

let ast;
try {
    ast = parser.parse(content, { tolerant: true });
} catch (err) {
    console.error(`Error parsing Solidity file: ${err.message}`);
    process.exit(1);
}

let permissions = null;

parser.visit(ast, {
    FunctionDefinition: function(node) {
        if (node.name === 'getHookPermissions') {
            node.body.statements.forEach(statement => {
                if (statement.type === 'ReturnStatement' && statement.expression.type === 'FunctionCall') {
                    const expr = statement.expression;
                    if (expr.expression.type === 'MemberAccess' &&
                        expr.expression.name === 'Permissions') {
                        const args = expr.arguments;
                        if (args.length === 1 && args[0].type === 'StructExpression') {
                            permissions = args[0].members;
                        }
                    }
                }
            });
        }
    }
});

if (!permissions) {
    console.error("Error: Could not find the getHookPermissions function or Permissions object.");
    process.exit(1);
}

// Extract hooks set to true
const trueHooks = permissions
    .filter(member => member.value.type === 'BooleanLiteral' && member.value.value === true)
    .map(member => member.name);

console.log(`Hooks set to true: ${trueHooks}`);

if (trueHooks.length === 0) {
    console.log("No hooks are set to true in Permissions. No actions needed.");
    process.exit(0);
}

// Extract all function names
const implementedFunctions = new Set();

parser.visit(ast, {
    FunctionDefinition: function(node) {
        if (node.name) {
            implementedFunctions.add(node.name);
        }
    }
});

// Find missing hooks
const missingHooks = trueHooks.filter(hook => !implementedFunctions.has(hook));

if (missingHooks.length > 0) {
    console.log("Missing implementations for the following hook functions:");
    missingHooks.forEach(hook => {
        console.log(`- ${hook}`);
    });
    process.exit(1);
} else {
    console.log("All hooks set to true have corresponding function implementations.");
}
