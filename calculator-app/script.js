class Calculator {
    constructor() {
        this.display = document.getElementById('display');
        this.history = document.getElementById('history');
        this.currentInput = '0';
        this.previousInput = null;
        this.operation = null;
        this.resetNextInput = false;
        this.historyList = [];
        this.initializeEventListeners();
    }
    
    initializeEventListeners() {
        document.querySelectorAll('.btn').forEach(button => {
            button.addEventListener('click', () => {
                this.handleButtonClick(button.dataset.value);
            });
        });
        document.addEventListener('keydown', (event) => {
            this.handleKeyboardInput(event);
        });
    }
    
    handleButtonClick(value) {
        switch(value) {
            case 'AC': this.allClear(); break;
            case 'C': this.clear(); break;
            case '=': this.calculate(); break;
            case '+': case '-': case '*': case '/': case '%': this.setOperation(value); break;
            case '.': this.addDecimal(); break;
            default: this.addNumber(value);
        }
        this.updateDisplay();
    }
    
    handleKeyboardInput(event) {
        const key = event.key;
        if ('0123456789+-*/=.'.includes(key) || key === 'Enter' || key === 'Escape' || key === 'Backspace') {
            event.preventDefault();
        }
        switch(key) {
            case 'Escape': this.allClear(); break;
            case 'Backspace': this.clear(); break;
            case 'Enter': case '=': this.calculate(); break;
            case '+': this.setOperation('+'); break;
            case '-': this.setOperation('-'); break;
            case '*': this.setOperation('*'); break;
            case '/': this.setOperation('/'); break;
            case '%': this.percentage(); break;
            case '.': this.addDecimal(); break;
            case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9': this.addNumber(key); break;
        }
        this.updateDisplay();
    }
    
    addNumber(number) {
        if (this.resetNextInput) {
            this.currentInput = '0';
            this.resetNextInput = false;
        } else if (this.currentInput === '0') {
            this.currentInput = number;
        } else {
            this.currentInput += number;
        }
    }
    
    addDecimal() {
        if (this.resetNextInput) {
            this.currentInput = '0.';
            this.resetNextInput = false;
            return;
        }
        if (!this.currentInput.includes('.')) this.currentInput += '.';
    }
    
    setOperation(operation) {
        if (this.operation !== null && !this.resetNextInput) this.calculate();
        this.previousInput = parseFloat(this.currentInput);
        this.operation = operation;
        this.resetNextInput = true;
    }
    
    calculate() {
        if (this.operation === null || this.previousInput === null) return;
        const prev = this.previousInput;
        const current = parseFloat(this.currentInput);
        let result;
        const calculation = `${prev} ${this.operation} ${current}`;
        
        switch(this.operation) {
            case '+': result = prev + current; break;
            case '-': result = prev - current; break;
            case '*': result = prev * current; break;
            case '/': 
                if (current === 0) {
                    this.display.textContent = 'Error';
                    return;
                }
                result = prev / current; 
                break;
            case '%': result = prev % current; break;
            default: return;
        }
        
        this.addToHistory(`${calculation} = ${result}`);
        result = this.formatResult(result);
        this.currentInput = result.toString();
        this.operation = null;
        this.previousInput = null;
        this.resetNextInput = true;
    }
    
    percentage() {
        const current = parseFloat(this.currentInput);
        this.currentInput = (current / 100).toString();
        this.updateDisplay();
    }
    
    clear() { this.currentInput = '0'; }
    
    allClear() {
        this.currentInput = '0';
        this.previousInput = null;
        this.operation = null;
        this.resetNextInput = false;
    }
    
    formatResult(result) {
        if (Number.isInteger(result)) return result;
        const rounded = Math.round(result * 10000000000) / 10000000000;
        return parseFloat(rounded.toFixed(10)).toString();
    }
    
    addToHistory(calculation) {
        this.historyList.unshift(calculation);
        if (this.historyList.length > 5) this.historyList.pop();
        this.updateHistoryDisplay();
    }
    
    updateHistoryDisplay() {
        this.history.textContent = this.historyList.join('\n');
    }
    
    updateDisplay() {
        let displayValue = this.currentInput;
        if (displayValue.length > 10) {
            const num = parseFloat(displayValue);
            if (Math.abs(num) > 9999999999) displayValue = num.toExponential(6);
            else displayValue = displayValue.substring(0, 10);
        }
        this.display.textContent = displayValue;
    }
}

// Initialize calculator when the page loads
document.addEventListener('DOMContentLoaded', () => {
    const calculator = new Calculator();
});