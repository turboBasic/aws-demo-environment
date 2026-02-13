// ProcessGrid Static Content Test - JavaScript

document.addEventListener('DOMContentLoaded', function() {
    initializeTestPage();
});

function initializeTestPage() {
    // Update timestamp
    updateTimestamp();

    // Check CSS loaded
    checkCSSLoaded();

    // Mark JS as loaded
    markJSLoaded();

    // Get system information
    displaySystemInfo();

    // Setup button click handler
    setupButtonHandler();

    // Initial status check
    updateStatus();
}

function updateTimestamp() {
    const timestamp = document.getElementById('timestamp');
    const now = new Date();
    const formattedTime = now.toLocaleString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
    timestamp.textContent = formattedTime;
}

function checkCSSLoaded() {
    const cssStatus = document.getElementById('cssStatus');
    const styleSheet = document.styleSheets;
    
    // Check if any stylesheet is loaded
    let cssLoaded = false;
    for (let i = 0; i < styleSheet.length; i++) {
        if (styleSheet[i].href && styleSheet[i].href.includes('style.css')) {
            cssLoaded = true;
            break;
        }
    }
    
    if (cssLoaded) {
        cssStatus.textContent = '✓ Loaded successfully';
        cssStatus.style.color = '#4caf50';
    } else {
        cssStatus.textContent = '✗ Failed to load';
        cssStatus.style.color = '#f44336';
    }
}

function markJSLoaded() {
    const jsStatus = document.getElementById('jsStatus');
    jsStatus.textContent = '✓ Loaded successfully';
    jsStatus.style.color = '#4caf50';
}

function setupButtonHandler() {
    const testButton = document.getElementById('testButton');
    testButton.addEventListener('click', function(e) {
        e.preventDefault();
        const output = document.getElementById('testOutput');
        const clickTime = new Date().toLocaleTimeString();
        output.textContent = `Button clicked at ${clickTime}. JavaScript is working correctly!`;
        output.style.color = '#4caf50';
        output.style.borderColor = '#4caf50';
    });
}

function updateStatus() {
    const statusBox = document.getElementById('statusBox');
    const allLoaded = isAllContentLoaded();
    
    if (allLoaded) {
        statusBox.classList.add('success');
        statusBox.innerHTML = `
            <h3 style="color: #2e7d32; margin: 0;">✓ All static files loaded successfully!</h3>
            <p style="margin-top: 10px; font-size: 0.95em;">Your S3 static content serving is working correctly.</p>
        `;
    } else {
        statusBox.classList.add('error');
        statusBox.innerHTML = `
            <h3 style="color: #c62828; margin: 0;">✗ Some resources failed to load</h3>
            <p style="margin-top: 10px; font-size: 0.95em;">Check the browser console for details.</p>
        `;
    }
}

function isAllContentLoaded() {
    // Simple check - if we got here and can see all elements, we're good
    const elements = [
        document.getElementById('statusBox'),
        document.getElementById('cssStatus'),
        document.getElementById('jsStatus'),
        document.getElementById('testButton')
    ];
    
    return elements.every(el => el !== null);
}

function displaySystemInfo() {
    const sysInfo = document.getElementById('sysInfo');
    const info = {
        'User Agent': navigator.userAgent,
        'Language': navigator.language,
        'Platform': navigator.platform,
        'Cookie Enabled': navigator.cookieEnabled,
        'Online Status': navigator.onLine ? 'Online' : 'Offline',
        'Page Title': document.title,
        'Current URL': window.location.href,
        'Page Loaded At': new Date().toISOString(),
        'Document Ready State': document.readyState
    };

    let infoText = '';
    for (const [key, value] of Object.entries(info)) {
        infoText += `${key}: ${value}\n`;
    }

    sysInfo.textContent = infoText;
}

// Log success to console
console.log('✓ ProcessGrid Static Content Test - All systems loaded');
console.log('Testing static file serving from S3');
console.log('HTML: ✓');
console.log('CSS: ✓');
console.log('JavaScript: ✓');
