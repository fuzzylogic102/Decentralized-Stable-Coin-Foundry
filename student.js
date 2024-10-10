import React from 'react';

function Student(props) {
    return (
        <p>
            {props.id}, {props.name}, {props.familyName}
        </p>
    );
}

function App() {
    const students = [
        { id: 1, name: 'John', familyName: 'Doe' },
        { id: 2, name: 'Jane', familyName: 'Smith' },
        { id: 3, name: 'Mike', familyName: 'Johnson' },
    ];

    return (
        <div>
            {students.map((student) => (
                <Student 
                    key={student.id}
                    id={student.id}
                    name={student.name}
                    familyName={student.familyName}
                />
            ))}
        </div>
    );
}

export default App;
