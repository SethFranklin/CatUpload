
const API_DOMAIN = '';

window.onload = async function() {
    const catsListElement = document.getElementById('cats');

    const response = await fetch(API_DOMAIN + '/api/cats', { method: 'GET' });
    const cats = await response.json();

    for (const cat of cats) {
        const date = new Date(0);
        date.setUTCMilliseconds(cat.created_timestamp);
        catsListElement.innerHTML += `
            <li>
                <img src="/cats/${cat.image}"><br>
                Name: ${cat.name}<br>
                Age: ${cat.age}<br>
                Upload time: ${date}
            </li>
        `;
    }

    const nameElement = document.getElementById('name');
    const ageElement = document.getElementById('age');
    const imageElement = document.getElementById('image');
    const buttonElement = document.getElementById('button');

    const fileDataURL = file => new Promise((resolve,reject) => {
        let fr = new FileReader();
        fr.onload = () => resolve( fr.result);
        fr.onerror = reject;
        fr.readAsDataURL(file)
    });

    buttonElement.onclick = async function() {
        const image = await fileDataURL(imageElement.files[0]);

        const response = await fetch(API_DOMAIN + '/api/cats', {
            method: 'POST',
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                name: nameElement.value,
                age: ageElement.value,
                image
            })
        });
        const result = await response.json();
        location.reload();
    };
};
