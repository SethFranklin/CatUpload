
const API_DOMAIN = 'http://18.211.209.47:3000';

window.onload = async function() {
    const catsListElement = document.getElementById('cats');

    const response = await fetch(API_DOMAIN + '/api/cats', { method: 'GET' });
    const cats = await response.json();

    for (const cat of cats) {
        console.log(cat);
        const date = new Date(0);
        date.setUTCMilliseconds(cat[1]);
        catsListElement.innerHTML += `
            <li>
                <img src="/cats/${cat[4]}"><br>
                Name: ${cat[2]}<br>
                Age: ${cat[3]}<br>
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
        fr.readAsDataURL(file);
    });

    buttonElement.onclick = async function() {
        const image = await fileDataURL(imageElement.files[0]);

        const response = await fetch(API_DOMAIN + '/api/cats', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
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
