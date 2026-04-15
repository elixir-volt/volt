let timer: ReturnType<typeof setInterval> | undefined;

export function startClock(el: HTMLElement) {
  const update = () => {
    el.textContent = new Date().toLocaleTimeString();
  };

  update();
  timer = setInterval(update, 1000);
}

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    if (timer) clearInterval(timer);
  });
  import.meta.hot.accept();
}
