class Calculator {
    constructor(displayEl, historyEl) {
        this.displayEl = displayEl;
        this.historyEl = historyEl;
        this.clearAll();
        this.history = [];
    }

    clearAll() {
        this.currentValue = '0';
        this.previousValue = null;
        this.operator = null;
        this.resetDisplay = false;
        this.updateDisplay();
    }

    clearEntry() {
        this.currentValue = '0';
        this.updateDisplay();
    }

    backspace() {
        if (this.currentValue.length > 1) {
            this.currentValue = this.currentValue.slice(0, -1);
        } else {
            this.currentValue = '0';
        }
        this.updateDisplay();
    }

    inputNumber(num) {
        if (this.resetDisplay || this.currentValue === '0') {
            this.currentValue = num;
            this.resetDisplay = false;
        } else {
            this.currentValue += num;
        }
        this.updateDisplay();
    }

    inputDecimal() {
        if (!this.currentValue.includes('.')) {
            this.currentValue += '.';
            this.updateDisplay();
        }
    }

    handleOperator(op) {
        if (this.previousValue !== null && this.operator !== null && !this.resetDisplay) {
            this.calculate();
        }
        this.previousValue = this.currentValue;
        this.operator = op;
        this.resetDisplay = true;
    }

    calculate() {
        const prev = parseFloat(this.previousValue);
        const current = parseFloat(this.currentValue);
        let result;

        switch (this.operator) {
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
                    this.displayError("Cannot divide by zero");
                    return;
                }
                result = prev / current;
                break;
            default:
                return;
        }
        
        const resultString = `${prev} ${this.getOperatorSymbol(this.operator)} ${current} = ${this.formatResult(result)}`;
        this.addToHistory(resultString);
        this.currentValue = this.formatResult(result).toString();
        this.previousValue = null;
        this.operator = null;
        this.updateDisplay();
    }
    
    formatResult(result) {
        return parseFloat(result.toPrecision(15));
    }

    getOperatorSymbol(op) {
        const symbols = { '+': '+', '-': '−', '*': '×', '/': '÷' };
        return symbols[op] || op;
    }

    addToHistory(calculation) {
        this.history.unshift(calculation);
        if (this.history.length > 5) {
            this.history.pop();
        }
        this.updateHistory();
    }

    updateHistory() {
        this.historyEl.innerHTML = this.history.map(calc => `<div>${calc}</div>`).join('');
    }

    updateDisplay() {
        this.displayEl.textContent = this.currentValue;
    }

    displayError(message) {
        this.currentValue = 'Error';
        this.updateDisplay();
        setTimeout(() => {
            this.clearAll();
        }, 2000);
    }

    handleButtonClick(e) {
        const btn = e.target;
        const action = btn.dataset.action;
        const num = btn.dataset.num;

        if (num !== undefined) {
            this.inputNumber(num);
        } else if (action) {
            switch (action) {
                case 'clear':
                    this.clearAll();
                    break;
                case 'clear-entry':
                    this.clearEntry();
                    break;
                case 'backspace':
                    this.backspace();
                    break;
                case '.':
                    this.inputDecimal();
                    break;
                case '+':
                case '-':
                case '*':
                case '/':
                    this.handleOperator(action);
                    break;
                case '=':
                    this.calculate();
                    break;
            }
        }
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const display = document.getElementById('display');
    const historyDiv = document.getElementById('history');
    const buttons = document.querySelectorAll('.btn');

    const calculator = new Calculator(display, historyDiv);

    buttons.forEach(button => {
        button.addEventListener('click', (e) => calculator.handleButtonClick(e));
    });

    document.addEventListener('keydown', (e) => {
        if (e.key >= '0' && e.key <= '9') {
            calculator.inputNumber(e.key);
        } else if (e.key === '.') {
            calculator.inputDecimal();
        } else if (e.key === 'Enter' || e.key === '=') {
            e.preventDefault();
            calculator.calculate();
        } else if (e.key === '+' || e.key === '-' || e.key === '*' || e.key === '/') {
            calculator.handleOperator(e.key);
        } else if (e.key === 'Escape') {
            calculator.clearAll();
        } else if (e.key === 'Backspace') {
            calculator.backspace();
        }
    });
});