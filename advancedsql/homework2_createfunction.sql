set search_path = hr;

--Задание 1. Напишите функцию, которая принимает на вход название должности (например, стажер), 
--а также даты периода поиска, и возвращает количество вакансий, опубликованных по этой должности в заданный период.

drop function if exists get_vacancy_count;
create function get_vacancy_count (pos_title_in text, date_from_in date, date_to_in date, out vacancy_count numeric) as $$
begin

select count(v.vac_id) into vacancy_count  from position p
left outer join vacancy v on v.pos_id  = p.pos_id  
where lower(p.pos_title) = lower(pos_title_in) and v.create_date between date_from_in and date_to_in
group by p.pos_title;
end;
$$ language plpgsql;


select get_vacancy_count('руководель трайба', '2020-01-01', '2023-01-01');

--Задание 2. Напишите триггер, срабатывающий тогда, когда в таблицу position добавляется значение grade, 
--которого нет в таблице-справочнике grade_salary. Триггер должен возвращать предупреждение пользователю о несуществующем значении grade.

drop trigger if exists verify_grade ON position;
create or replace function verify_grade() returns trigger as $$
declare temp_int int;
begin 
	select count(*) into temp_int from grade_salary g where g.grade = new.grade;
	if (temp_int = 0) THEN
            RAISE EXCEPTION 'Grade % is not found', NEW.grade;
   end if;
end;
$$ language plpgsql;
CREATE TRIGGER verify_grade BEFORE INSERT OR UPDATE ON position 
    FOR EACH ROW when (NEW.grade is not null) EXECUTE FUNCTION verify_grade();

insert into position(pos_id, pos_title, address_id, manager_pos_id, grade) values(4593, 'Temp position', 20, 4568, 4);
insert into position(pos_id, pos_title, address_id, manager_pos_id) values(4593, 'Temp position', 20, 4568);

--Задание 3. Создайте таблицу employee_salary_history с полями:
--emp_id - id сотрудника
--salary_old - последнее значение salary (если не найдено, то 0)
--salary_new - новое значение salary
--difference - разница между новым и старым значением salary
--last_update - текущая дата и время
--Напишите триггерную функцию, которая срабатывает при добавлении новой записи о сотруднике или при обновлении значения 
--salary в таблице employee_salary, и заполняет таблицу employee_salary_history данными.
drop table if exists employee_salary_history;
create table employee_salary_history (
	emp_id int not null references employee(emp_id), 
	salary_old int default 0, 
	salary_new int not null,
	difference int not null CONSTRAINT positive_price CHECK (difference > 0),
	last_update timestamp default current_timestamp
	);

drop trigger if exists write_employee_salary_history on employee_salary;

create or replace function write_employee_salary_history() returns trigger as $$
declare oldsal int;
begin 
	--try to find the last HISTORY cortage
	select salary_new into oldsal from employee_salary_history where emp_id = new.emp_id order by  last_update  desc limit 1;
if (oldsal is null) then
--no history, lets find smth in the table
	select salary into oldsal from employee_salary where emp_id = new.emp_id order by  order_id  asc  limit 1;
end if; 
insert into employee_salary_history (emp_id, salary_old, salary_new, difference)
values (new.emp_id, oldsal, new.salary, new.salary - coalesce(oldsal, 0));
return new;
end;

$$ language plpgsql;
CREATE TRIGGER write_employee_salary_history before INSERT OR UPDATE ON employee_salary 
    FOR EACH ROW EXECUTE FUNCTION write_employee_salary_history();
    
   
 --Задание 4. Напишите процедуру, которая содержит в себе транзакцию на вставку данных в таблицу employee_salary. 
--Входными параметрами являются поля таблицы employee_salary.

select * from employee_salary es 
   
create or replace procedure insert_new_salary(order_id_in int, emp_id_in int, salary_in int, effective_from_in date, mode_in boolean) as $$
begin
	insert into employee_salary (order_id, emp_id, salary, effective_from)  
		values(order_id_in, emp_id_in, salary_in, effective_from_in);
	if mode_in then
		commit;
	else
		rollback;
	end if;
end
$$ language plpgsql;

call insert_new_salary (60001, 274, 300000, '2023-12-01', false);

select * from employee_salary es where emp_id = 274
select * from employee_salary_history esh where emp_id = 274