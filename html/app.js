const app = document.getElementById('app');
const postsEl = document.getElementById('posts');
const emptyEl = document.getElementById('empty');
const modal = document.getElementById('modal');
const form = document.getElementById('post-form');
const imageInput = document.getElementById('image-url');
const bodyInput = document.getElementById('body-text');
const textSizeInput = document.getElementById('text-size');
const preview = document.getElementById('preview');
const imageViewer = document.getElementById('image-viewer');
const imageViewerPicture = document.getElementById('image-viewer-picture');
const imageViewerCaption = document.getElementById('image-viewer-caption');
const deleteConfirm = document.getElementById('delete-confirm');
const submit = document.getElementById('submit');
const newPost = document.getElementById('new-post');
let limits = {};
let postingAllowed = true;
let busy = false;
let pendingDeleteId = null;
let ui = {};

// Testo della lingua attiva (locales.lua); i segnaposto {nome} vengono sostituiti da vars.
function t(key, vars = {}, fallback = '') {
    const text = ui[key] ?? fallback;
    return String(text).replace(/\{(\w+)\}/g, (_, name) => vars[name] ?? '');
}

function applyTranslations(next) {
    if (!next) return;
    ui = next;
    document.documentElement.lang = ui.lang || 'it';
    document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n, {}, el.textContent); });
    document.querySelectorAll('[data-i18n-placeholder]').forEach((el) => { el.placeholder = t(el.dataset.i18nPlaceholder, {}, el.placeholder); });
    document.querySelectorAll('[data-i18n-aria]').forEach((el) => { el.setAttribute('aria-label', t(el.dataset.i18nAria, {}, el.getAttribute('aria-label'))); });
    document.querySelectorAll('[data-i18n-alt]').forEach((el) => { el.alt = t(el.dataset.i18nAlt, {}, el.alt); });
}

const nui = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
}).catch(() => null);

function setNight(value) { app.classList.toggle('night', Boolean(value)); }

function showImageViewer(show, source = '', caption = '') {
    imageViewer.classList.toggle('hidden', !show);
    if (show) {
        imageViewerPicture.src = source;
        imageViewerCaption.textContent = caption;
    } else {
        imageViewerPicture.removeAttribute('src');
        imageViewerCaption.textContent = '';
    }
}

function showDeleteConfirm(show, postId = null) {
    pendingDeleteId = show ? postId : null;
    deleteConfirm.classList.toggle('hidden', !show);
}

function setLimits(next = {}) {
    limits = next;
    document.getElementById('personal-limit').textContent = t('limits', {
        boardCount: next.boardCount || 0,
        boardMax: next.boardMax || 10,
        mine: next.mine || 0,
        mineMax: next.mineMax || 2,
    }, 'Manifesti totali: {boardCount} / {boardMax} · I tuoi annunci: {mine} / {mineMax}');
    const full = (next.boardCount || 0) >= (next.boardMax || 10) || (next.mine || 0) >= (next.mineMax || 2);
    newPost.disabled = !postingAllowed || full;
    newPost.classList.toggle('hidden', !postingAllowed);
    newPost.title = !postingAllowed ? t('postingReserved', {}, 'Pubblicazione riservata') : (full ? t('limitReached', {}, 'Limite annunci raggiunto') : '');
}

function setPostingAllowed(value) {
    postingAllowed = value !== false;
    setLimits(limits);
}

function formatDate(timestamp) {
    return new Intl.DateTimeFormat(ui.dateLocale || 'it-IT', { day: '2-digit', month: 'short' }).format(new Date(Number(timestamp) * 1000));
}

function renderPosts(posts = []) {
    postsEl.replaceChildren();
    emptyEl.classList.toggle('hidden', posts.length > 0);
    postsEl.classList.toggle('hidden', posts.length === 0);

    posts.forEach((post, index) => {
        const note = document.createElement('article');
        const textSize = ['small', 'normal', 'large'].includes(post.text_size) ? post.text_size : 'normal';
        note.className = `note note-size-${textSize}`;
        note.style.setProperty('--tilt', `${[-1.2, .7, -.35, 1, -.7][index % 5]}deg`);

        const title = document.createElement('h2');
        title.textContent = post.title;
        const body = document.createElement('p');
        body.textContent = post.body;
        note.append(title, body);

        if (post.image_url) {
            const image = document.createElement('img');
            image.src = post.image_url;
            image.alt = post.title;
            image.loading = 'lazy';
            image.referrerPolicy = 'no-referrer';
            image.addEventListener('error', () => image.remove());
            image.addEventListener('click', () => showImageViewer(true, post.image_url, post.title));
            note.append(image);
        }

        const meta = document.createElement('div');
        meta.className = 'note-meta';
        const expiry = document.createElement('span');
        expiry.textContent = t('expires', { date: formatDate(post.expires_at) }, 'scade {date}');
        if (post.owner_name) {
            const author = document.createElement('span');
            author.textContent = post.owner_name;
            meta.append(author);
        }
        meta.append(expiry);
        note.append(meta);

        if (post.canDelete) {
            const remove = document.createElement('button');
            remove.className = 'delete-note';
            remove.type = 'button';
            remove.textContent = '×';
            remove.title = t('removePost', {}, 'Rimuovi annuncio');
            remove.addEventListener('click', () => showDeleteConfirm(true, post.id));
            note.append(remove);
        }
        postsEl.append(note);
    });
}

function showModal(show) {
    modal.classList.toggle('hidden', !show);
    if (show) document.getElementById('title').focus();
    else {
        form.reset();
        textSizeInput.value = 'normal';
        document.querySelectorAll('[data-text-size]').forEach((button) => {
            button.classList.toggle('active', button.dataset.textSize === 'normal');
        });
        bodyInput.style.height = '';
        preview.classList.add('hidden');
        document.getElementById('form-error').classList.add('hidden');
    }
}

function setBusy(value) {
    busy = value;
    submit.disabled = value;
    submit.textContent = value ? t('submitting', {}, 'Affissione...') : t('submit', {}, 'AFFIGGI MANIFESTO');
}

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        applyTranslations(data.ui);
        setNight(data.isNight);
        setPostingAllowed(data.canPost);
        setLimits(data.limits);
        renderPosts(data.posts);
        app.classList.remove('hidden');
        app.setAttribute('aria-hidden', 'false');
    } else if (data.action === 'update') {
        renderPosts(data.posts);
        setPostingAllowed(data.canPost);
        setLimits(data.limits);
        setBusy(false);
        showModal(false);
    } else if (data.action === 'time') {
        setNight(data.isNight);
    } else if (data.action === 'busy') {
        setBusy(data.value);
    } else if (data.action === 'close') {
        app.classList.add('hidden');
        app.setAttribute('aria-hidden', 'true');
        showModal(false);
        showImageViewer(false);
        showDeleteConfirm(false);
    }
});

document.getElementById('close').addEventListener('click', () => nui('close'));
document.getElementById('modal-close').addEventListener('click', () => showModal(false));
document.getElementById('image-viewer-close').addEventListener('click', () => showImageViewer(false));
imageViewer.addEventListener('click', (event) => {
    if (event.target === imageViewer) showImageViewer(false);
});
document.getElementById('delete-cancel').addEventListener('click', () => showDeleteConfirm(false));
document.getElementById('delete-accept').addEventListener('click', () => {
    if (pendingDeleteId !== null) nui('delete', { id: pendingDeleteId });
    showDeleteConfirm(false);
});
deleteConfirm.addEventListener('click', (event) => {
    if (event.target === deleteConfirm) showDeleteConfirm(false);
});
newPost.addEventListener('click', () => showModal(true));

imageInput.addEventListener('input', () => {
    const value = imageInput.value.trim();
    preview.classList.toggle('hidden', !value);
    preview.querySelector('img').src = value;
});

bodyInput.addEventListener('input', () => {
    bodyInput.style.height = 'auto';
    bodyInput.style.height = `${Math.min(bodyInput.scrollHeight, 230)}px`;
    bodyInput.style.overflowY = bodyInput.scrollHeight > 230 ? 'auto' : 'hidden';
});

document.querySelectorAll('[data-text-size]').forEach((button) => {
    button.addEventListener('click', () => {
        textSizeInput.value = button.dataset.textSize;
        document.querySelectorAll('[data-text-size]').forEach((entry) => entry.classList.toggle('active', entry === button));
    });
});

form.addEventListener('submit', (event) => {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    nui('create', {
        title: document.getElementById('title').value,
        body: document.getElementById('body-text').value,
        imageUrl: imageInput.value,
        textSize: textSizeInput.value,
    });
});

document.addEventListener('keyup', (event) => {
    if (event.key !== 'Escape') return;
    if (!deleteConfirm.classList.contains('hidden')) showDeleteConfirm(false);
    else if (!imageViewer.classList.contains('hidden')) showImageViewer(false);
    else if (!modal.classList.contains('hidden')) showModal(false);
    else nui('close');
});
