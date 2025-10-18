/* MetaTrader Trading Systems Portfolio - Main Application */

(function() {
    'use strict';
    
    // Application state
    const AppState = {
        currentStrategy: 'gold-sma',
        performancePeriod: '1y',
        isLoading: false,
        userPreferences: {
            animations: true,
            darkMode: true,
            reducedMotion: false
        }
    };
    
    // Application initialization
    function initApp() {
        console.log('MetaTrader Trading Systems Portfolio - Initializing...');
        
        // Check for user preferences
        checkUserPreferences();
        
        // Initialize core features
        initCounterAnimations();
        initTooltips();
        initLazyLoading();
        initPerformanceMonitoring();
        initKeyboardNavigation();
        initErrorHandling();
        
        // Initialize advanced features
        initDataVisualization();
        initRealTimeUpdates();
        initAnalytics();
        
        console.log('MetaTrader Trading Systems Portfolio - Ready!');
    }
    
    // Check user preferences and apply settings
    function checkUserPreferences() {
        // Check for reduced motion preference
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            AppState.userPreferences.reducedMotion = true;
            document.body.classList.add('reduced-motion');
        }
        
        // Check for high contrast preference
        if (window.matchMedia('(prefers-contrast: high)').matches) {
            document.body.classList.add('high-contrast');
        }
        
        // Load saved preferences from localStorage
        const savedPreferences = localStorage.getItem('mt-portfolio-preferences');
        if (savedPreferences) {
            try {
                const preferences = JSON.parse(savedPreferences);
                Object.assign(AppState.userPreferences, preferences);
            } catch (e) {
                console.warn('Could not load user preferences:', e);
            }
        }
    }
    
    
    // Counter animations for statistics
    function initCounterAnimations() {
        const counters = document.querySelectorAll('.stat-value, .metric-value');
        
        const observerOptions = {
            threshold: 0.5,
            rootMargin: '0px'
        };
        
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    animateCounter(entry.target);
                    observer.unobserve(entry.target);
                }
            });
        }, observerOptions);
        
        counters.forEach(counter => {
            observer.observe(counter);
        });
    }
    
    // Animate individual counter
    function animateCounter(element) {
        if (AppState.userPreferences.reducedMotion) return;
        
        const text = element.textContent;
        const isPercentage = text.includes('%');
        const isRatio = text.includes(':');
        const isNegative = text.includes('-');
        const isCurrency = text.includes('$');
        
        let targetValue = parseFloat(text.replace(/[^\d.-]/g, ''));
        if (isNaN(targetValue)) return;
        
        const duration = 2000;
        const startTime = performance.now();
        const startValue = 0;
        
        function updateCounter(currentTime) {
            const elapsed = currentTime - startTime;
            const progress = Math.min(elapsed / duration, 1);
            
            // Easing function
            const easeOut = 1 - Math.pow(1 - progress, 3);
            const currentValue = startValue + (targetValue - startValue) * easeOut;
            
            let displayValue = Math.round(currentValue * 10) / 10;
            
            // Format the value
            if (isPercentage) {
                element.textContent = `${displayValue}%`;
            } else if (isRatio) {
                element.textContent = `${displayValue}:1`;
            } else if (isCurrency) {
                element.textContent = `$${displayValue.toLocaleString()}`;
            } else if (isNegative) {
                element.textContent = `-${displayValue}%`;
            } else {
                element.textContent = displayValue.toString();
            }
            
            if (progress < 1) {
                requestAnimationFrame(updateCounter);
            } else {
                element.textContent = text; // Restore original text
            }
        }
        
        requestAnimationFrame(updateCounter);
    }
    
    // Initialize tooltips
    function initTooltips() {
        const tooltipElements = document.querySelectorAll('[data-tooltip]');
        
        tooltipElements.forEach(element => {
            element.addEventListener('mouseenter', showTooltip);
            element.addEventListener('mouseleave', hideTooltip);
            element.addEventListener('focus', showTooltip);
            element.addEventListener('blur', hideTooltip);
        });
    }
    
    // Show tooltip
    function showTooltip(e) {
        const element = e.target;
        const tooltipText = element.getAttribute('data-tooltip');
        if (!tooltipText) return;
        
        const tooltip = document.createElement('div');
        tooltip.className = 'tooltip';
        tooltip.textContent = tooltipText;
        tooltip.style.cssText = `
            position: absolute;
            background: var(--secondary-bg);
            color: var(--text-primary);
            padding: 0.5rem 1rem;
            border-radius: var(--border-radius-small);
            border: 1px solid var(--border-color);
            font-size: 0.9rem;
            z-index: 10000;
            pointer-events: none;
            opacity: 0;
            transition: opacity 0.3s ease;
            box-shadow: var(--shadow-medium);
        `;
        
        document.body.appendChild(tooltip);
        
        // Position tooltip
        const rect = element.getBoundingClientRect();
        const tooltipRect = tooltip.getBoundingClientRect();
        
        tooltip.style.left = `${rect.left + (rect.width - tooltipRect.width) / 2}px`;
        tooltip.style.top = `${rect.top - tooltipRect.height - 10}px`;
        
        // Show tooltip
        setTimeout(() => {
            tooltip.style.opacity = '1';
        }, 10);
        
        element._tooltip = tooltip;
    }
    
    // Hide tooltip
    function hideTooltip(e) {
        const element = e.target;
        if (element._tooltip) {
            element._tooltip.remove();
            delete element._tooltip;
        }
    }
    
    // Lazy loading for images and content
    function initLazyLoading() {
        const lazyElements = document.querySelectorAll('[data-lazy]');
        
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '50px'
        };
        
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    loadElement(entry.target);
                    observer.unobserve(entry.target);
                }
            });
        }, observerOptions);
        
        lazyElements.forEach(element => {
            observer.observe(element);
        });
    }
    
    // Load lazy element
    function loadElement(element) {
        const src = element.getAttribute('data-lazy');
        const type = element.getAttribute('data-type') || 'image';
        
        if (type === 'image') {
            const img = new Image();
            img.onload = () => {
                element.src = src;
                element.classList.add('loaded');
            };
            img.src = src;
        } else if (type === 'content') {
            // Load dynamic content
            fetch(src)
                .then(response => response.text())
                .then(html => {
                    element.innerHTML = html;
                    element.classList.add('loaded');
                })
                .catch(error => {
                    console.error('Error loading content:', error);
                    element.innerHTML = '<p>Error loading content</p>';
                });
        }
    }
    
    // Performance monitoring
    function initPerformanceMonitoring() {
        // Monitor page load performance
        window.addEventListener('load', () => {
            if ('performance' in window) {
                const loadTime = performance.timing.loadEventEnd - performance.timing.navigationStart;
                console.log(`Page load time: ${loadTime}ms`);
                
                // Track Core Web Vitals
                if ('web-vitals' in window) {
                    // This would use the web-vitals library if included
                    trackWebVitals();
                }
            }
        });
        
        // Monitor long tasks
        if ('PerformanceObserver' in window) {
            try {
                const observer = new PerformanceObserver((list) => {
                    list.getEntries().forEach((entry) => {
                        if (entry.duration > 50) {
                            console.warn(`Long task detected: ${entry.duration}ms`);
                        }
                    });
                });
                observer.observe({ entryTypes: ['longtask'] });
            } catch (e) {
                console.warn('Performance monitoring not supported');
            }
        }
    }
    
    // Track Core Web Vitals (simplified)
    function trackWebVitals() {
        // Largest Contentful Paint (LCP)
        new PerformanceObserver((entryList) => {
            const entries = entryList.getEntries();
            const lastEntry = entries[entries.length - 1];
            console.log('LCP:', lastEntry.startTime);
        }).observe({ entryTypes: ['largest-contentful-paint'] });
        
        // First Input Delay (FID)
        new PerformanceObserver((entryList) => {
            const firstInput = entryList.getEntries()[0];
            console.log('FID:', firstInput.processingStart - firstInput.startTime);
        }).observe({ entryTypes: ['first-input'] });
        
        // Cumulative Layout Shift (CLS)
        let clsValue = 0;
        new PerformanceObserver((entryList) => {
            for (const entry of entryList.getEntries()) {
                if (!entry.hadRecentInput) {
                    clsValue += entry.value;
                }
            }
            console.log('CLS:', clsValue);
        }).observe({ entryTypes: ['layout-shift'] });
    }
    
    
    // Keyboard navigation
    function initKeyboardNavigation() {
        document.addEventListener('keydown', (e) => {
            
            // Alt + T: Switch tabs
            if (e.altKey && e.key === 't') {
                e.preventDefault();
                const activeTab = document.querySelector('.tab-btn.active');
                const allTabs = document.querySelectorAll('.tab-btn');
                const currentIndex = Array.from(allTabs).indexOf(activeTab);
                const nextIndex = (currentIndex + 1) % allTabs.length;
                allTabs[nextIndex].click();
            }
            
            // Escape: Close modals
            if (e.key === 'Escape') {
                const modal = document.querySelector('.modal');
                if (modal) {
                    modal.querySelector('.modal-close').click();
                }
            }
            
            // Arrow keys: Navigate strategy cards
            if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
                const strategyCards = document.querySelectorAll('.strategy-card');
                const focusedCard = document.activeElement.closest('.strategy-card');
                if (focusedCard) {
                    const currentIndex = Array.from(strategyCards).indexOf(focusedCard);
                    let nextIndex;
                    
                    if (e.key === 'ArrowLeft') {
                        nextIndex = currentIndex > 0 ? currentIndex - 1 : strategyCards.length - 1;
                    } else {
                        nextIndex = currentIndex < strategyCards.length - 1 ? currentIndex + 1 : 0;
                    }
                    
                    strategyCards[nextIndex].focus();
                    e.preventDefault();
                }
            }
        });
        
        // Make strategy cards focusable
        const strategyCards = document.querySelectorAll('.strategy-card');
        strategyCards.forEach((card, index) => {
            card.setAttribute('tabindex', '0');
            card.setAttribute('role', 'button');
            card.setAttribute('aria-label', `Strategy ${index + 1}`);
            
            card.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    const learnMoreBtn = card.querySelector('.learn-more-btn');
                    if (learnMoreBtn) {
                        learnMoreBtn.click();
                    }
                }
            });
        });
    }
    
    // Error handling
    function initErrorHandling() {
        window.addEventListener('error', (e) => {
            console.error('JavaScript error:', e.error);
            showErrorNotification('An unexpected error occurred. Please refresh the page.');
        });
        
        window.addEventListener('unhandledrejection', (e) => {
            console.error('Unhandled promise rejection:', e.reason);
            showErrorNotification('A network error occurred. Please check your connection.');
        });
    }
    
    // Show error notification
    function showErrorNotification(message) {
        const notification = document.createElement('div');
        notification.className = 'error-notification';
        notification.textContent = message;
        notification.style.cssText = `
            position: fixed;
            top: 100px;
            right: 2rem;
            background: var(--danger-color);
            color: white;
            padding: 1rem 2rem;
            border-radius: var(--border-radius-small);
            z-index: 10000;
            opacity: 0;
            transform: translateX(100%);
            transition: all 0.3s ease;
            max-width: 300px;
            box-shadow: var(--shadow-medium);
        `;
        
        document.body.appendChild(notification);
        
        // Show notification
        setTimeout(() => {
            notification.style.opacity = '1';
            notification.style.transform = 'translateX(0)';
        }, 10);
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            notification.style.opacity = '0';
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => notification.remove(), 300);
        }, 5000);
    }
    
    // Data visualization
    function initDataVisualization() {
        // This would integrate with Chart.js or D3.js for real charts
        const chartPlaceholders = document.querySelectorAll('.chart-placeholder');
        
        chartPlaceholders.forEach(placeholder => {
            placeholder.addEventListener('click', () => {
                showMockChart(placeholder);
            });
        });
    }
    
    // Show mock chart (would be real chart in production)
    function showMockChart(placeholder) {
        const canvas = document.createElement('canvas');
        canvas.width = 800;
        canvas.height = 400;
        canvas.style.cssText = `
            width: 100%;
            height: 300px;
            background: var(--accent-bg);
            border-radius: var(--border-radius-small);
            border: 1px solid var(--border-color);
        `;
        
        placeholder.innerHTML = '';
        placeholder.appendChild(canvas);
        
        // Mock chart drawing
        const ctx = canvas.getContext('2d');
        ctx.strokeStyle = '#ffd700';
        ctx.lineWidth = 2;
        ctx.beginPath();
        
        for (let i = 0; i < canvas.width; i += 10) {
            const y = 200 + Math.sin(i * 0.01) * 50 + Math.random() * 20;
            if (i === 0) {
                ctx.moveTo(i, y);
            } else {
                ctx.lineTo(i, y);
            }
        }
        
        ctx.stroke();
        
        // Add chart title
        const title = document.createElement('h4');
        title.textContent = 'Performance Chart (Interactive)';
        title.style.cssText = `
            position: absolute;
            top: 1rem;
            left: 1rem;
            color: var(--accent-color);
            margin: 0;
        `;
        placeholder.style.position = 'relative';
        placeholder.appendChild(title);
    }
    
    // Real-time updates simulation
    function initRealTimeUpdates() {
        // Simulate real-time performance updates every 30 seconds
        setInterval(() => {
            updateRealTimeMetrics();
        }, 30000);
    }
    
    // Update real-time metrics
    function updateRealTimeMetrics() {
        const metricCards = document.querySelectorAll('.metric-card .metric-value');
        
        metricCards.forEach(metric => {
            const currentValue = parseFloat(metric.textContent.replace(/[^\d.-]/g, ''));
            if (!isNaN(currentValue)) {
                // Add small random fluctuation
                const fluctuation = (Math.random() - 0.5) * 0.1;
                const newValue = currentValue + fluctuation;
                
                // Update with animation
                metric.style.transition = 'all 0.3s ease';
                metric.style.transform = 'scale(1.05)';
                
                setTimeout(() => {
                    metric.textContent = metric.textContent.replace(currentValue.toString(), newValue.toFixed(1));
                    metric.style.transform = 'scale(1)';
                }, 150);
            }
        });
    }
    
    // Analytics tracking
    function initAnalytics() {
        // Track user interactions
        document.addEventListener('click', (e) => {
            const element = e.target;
            const trackingData = {
                element: element.tagName.toLowerCase(),
                className: element.className,
                timestamp: new Date().toISOString(),
                section: element.closest('section')?.id || 'unknown'
            };
            
            // Log interaction (would send to analytics service in production)
            console.log('User interaction:', trackingData);
        });
        
        // Track scroll depth
        let maxScrollDepth = 0;
        window.addEventListener('scroll', () => {
            const scrollPercent = Math.round((window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100);
            if (scrollPercent > maxScrollDepth) {
                maxScrollDepth = scrollPercent;
                console.log('Max scroll depth:', maxScrollDepth + '%');
            }
        });
        
        // Track time on page
        const startTime = Date.now();
        window.addEventListener('beforeunload', () => {
            const timeOnPage = Date.now() - startTime;
            console.log('Time on page:', Math.round(timeOnPage / 1000) + ' seconds');
        });
    }
    
    // Public API
    window.MetaTraderPortfolio = {
        state: AppState,
        init: initApp,
        showError: showErrorNotification,
    };
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initApp);
    } else {
        initApp();
    }
    
})();