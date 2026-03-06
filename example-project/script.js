// Calculator state
let currentValue = '0';
let previousValue = '';
let operator = null;
let shouldResetDisplay = false;

const resultDisplay = document.getElementById('result');
const expressionDisplay = document.getElementById('expression');

// Update the display
function updateDisplay() {
    resultDisplay.textContent = currentValue;
    if (previousValue && operator) {
        const opSymbol = getOperatorSymbol(operator);
        expressionDisplay.textContent = `${previousValue} ${opSymbol}`;
    } else {
        expressionDisplay.textContent = '';
    }
}

// Get display-friendly operator symbol
function getOperatorSymbol(op) {
    const symbols = {
        '+': '+',
        '-': '−',
        '*': '×',
        '/': '÷'
    };
    return symbols[op] || op;
}

// Append a number to the display
function appendNumber(num) {
    if (shouldResetDisplay) {
        currentValue = num;
        shouldResetDisplay = false;
    } else if (currentValue === '0' && num !== '.') {
        currentValue = num;
    } else if (currentValue.length < 15) {
        currentValue += num;
    }
    updateDisplay();
}

// Append a decimal point
function appendDecimal() {
    if (shouldResetDisplay) {
        currentValue = '0.';
        shouldResetDisplay = false;
    } else if (!currentValue.includes('.')) {
        currentValue += '.';
    }
    updateDisplay();
}

// Append an operator
function appendOperator(op) {
    if (operator && !shouldResetDisplay) {
        calculate();
    }
    previousValue = currentValue;
    operator = op;
    shouldResetDisplay = true;
    updateDisplay();
}

// Calculate the result
function calculate() {
    if (!operator || !previousValue) return;
    
    const prev = parseFloat(previousValue);
    const current = parseFloat(currentValue);
    let result;

    switch (operator) {
        case '+':
            result = prev + current;
            break;
        case '-':
            result = prev - current;
            break;
        case '*':
            result = prev * current;
            break;
        case '/':
            if (current === 0) {
                result = 'Error';
            } else {
                result = prev / current;
            }
            break;
        default:
            return;
    }

    // Format the result
    if (result === 'Error') {
        currentValue = 'Error';
    } else {
        // Round to avoid floating point issues
        result = Math.round(result * 1000000000) / 1000000000;
        currentValue = result.toString();
        
        // Limit display length
        if (currentValue.length > 12) {
            currentValue = parseFloat(currentValue).toExponential(6);
        }
    }
    
    operator = null;
    previousValue = '';
    shouldResetDisplay = true;
    updateDisplay();
}

// Clear all
function clearAll() {
    currentValue = '0';
    previousValue = '';
    operator = null;
    shouldResetDisplay = false;
    updateDisplay();
}

// Toggle sign (+/-)
function toggleSign() {
    if (currentValue !== '0' && currentValue !== 'Error') {
        if (currentValue.startsWith('-')) {
            currentValue = currentValue.substring(1);
        } else {
            currentValue = '-' + currentValue;
        }
        updateDisplay();
    }
}

// Calculate percentage
function percentage() {
    if (currentValue !== 'Error') {
        currentValue = (parseFloat(currentValue) / 100).toString();
        updateDisplay();
    }
}

// Keyboard support
document.addEventListener('keydown', (e) => {
    if (e.key >= '0' && e.key <= '9') {
        appendNumber(e.key);
    } else if (e.key === '.') {
        appendDecimal();
    } else if (e.key === '+') {
        appendOperator('+');
    } else if (e.key === '-') {
        appendOperator('-');
    } else if (e.key === '*') {
        appendOperator('*');
    } else if (e.key === '/') {
        e.preventDefault();
        appendOperator('/');
    } else if (e.key === 'Enter' || e.key === '=') {
        calculate();
    } else if (e.key === 'Escape' || e.key === 'c' || e.key === 'C') {
        clearAll();
    } else if (e.key === 'Backspace') {
        if (currentValue.length > 1) {
            currentValue = currentValue.slice(0, -1);
        } else {
            currentValue = '0';
        }
        updateDisplay();
    } else if (e.key === '%') {
        percentage();
    }
});

// Initialize display
updateDisplay();